#!/bin/bash

# check if the session database exists, and delete it if so
# this allows the stats of each call within the loop to be accurately aggregated
session_db_path="/root/.local/share/opencode/opencode.db"

if [ -f "$session_db_path" ]; then
    rm -rf "$session_db_path"
    echo "OpenCode session db deleted."
fi

PASSED=false
MAX_ITERATIONS=5
ITERATION=0

# start the evaluation loop
while [ "$PASSED" = false ] && [ $ITERATION -lt $MAX_ITERATIONS ]; do
    ((ITERATION++))
    echo "🔄 Starting Loop Iteration $ITERATION..."

    # Run the tester to generate/improve tests
    opencode run --agent="tester" --auto "Write or update tests that: 1. Match the plan in plan.md 2. Address any feedback in .review_status.md"
    
    # Run the builder, explicitly telling it to look at the reviewer's feedback if it exists
    opencode run --agent="builder" --auto "Update the source code to address failing tests. Check .review_status.md for any specific bugs flagged during review."
    
    # Run the reviewer and force it to output a strict, machine-readable gate condition
    opencode run --agent="reviewer" --auto "If everything passes perfectly, write ONLY the word 'PASSED' to .review_status.md. If there are bugs or mismatches, write 'FAILED' followed by a detailed list of what to fix to .review_status.md."

    # 3. Check the Gate Condition
    if grep -q "PASSED" .review_status.md; then
        PASSED=true
        echo "🎉 Review passed successfully on iteration $ITERATION!"
        rm .review_status.md  # Clean up state file
        opencode stats > session_stats.txt
    else
        echo "❌ Review failed. Feedback cycled back to the tester & builder."
    fi
done

if [ "$PASSED" = false ]; then
    echo "⚠️ Loop terminated: Reached maximum iterations ($MAX_ITERATIONS) without a successful review."
    opencode stats > session_stats.txt
    exit 1
fi