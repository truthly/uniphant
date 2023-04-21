#!python3
import requests
import json
import traceback
from uniphant.worker import worker, alive

def next(connection):
    cursor = connection.cursor()
    cursor.execute("""
        SELECT opentdb.get_trivia_question_next()
    """)
    return cursor.fetchone()[0]

def set_response(connection, id, response):
    connection.cursor().execute("""
        SELECT opentdb.get_trivia_question_set_response(%s, %s)
    """, (id, json.dumps(response)))

def set_error(connection, id, error):
    connection.cursor().execute("""
        SELECT opentdb.get_trivia_question_set_error(%s, %s)
    """, (id, error))

def get_trivia_question(connection, config, state, logger):
    while alive(connection, state.foreground):
        id = next(connection)
        if id is None:
            return

        try:
            logger.info(f'Getting Question for {id}')

            url = 'https://opentdb.com/api.php?amount=1'
            response = requests.get(url)
            response.raise_for_status()

            set_response(connection, id, response.json())

            logger.info(f'Got Question for {id}')

        except Exception as e:
            tb = traceback.format_exc()
            error = f'{e}\n{tb}'
            logger.error(error)
            set_error(connection, id, error)

if __name__ == "__main__":
    worker(get_trivia_question)
