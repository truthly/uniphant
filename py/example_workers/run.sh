#!/bin/bash
python3 api_integrations/opentdb/get_trivia_question.py "$@" &
python3 api_integrations/wikipedia/search.py "$@" &

# Wait for both processes to complete
wait
