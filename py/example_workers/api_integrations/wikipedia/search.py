#!python3
import requests
import json
import html
from uniphant import *

def next(connection):
    cursor = connection.cursor()
    cursor.execute("""
        SELECT id, question FROM wikipedia.search_next()
    """)
    return cursor.fetchone()

def set_response(connection, id, response):
    connection.cursor().execute("""
        SELECT wikipedia.search_set_response(%s, %s)
    """, (id, json.dumps(response)))

def set_error(connection, id, error):
    cursor = connection.cursor().execute("""
        SELECT wikipedia.search_set_error(%s, %s)
    """, (id, error))

def search(config, logger, connection):
    while alive(config, connection):
        id, question = next(connection)
        if id is None:
            return

        try:
            logger.info(f'Getting Answer for {id}')

            url = 'https://en.wikipedia.org/w/api.php'
            params = {
                'action': 'query',
                'list': 'search',
                'format': 'json',
                'srsearch': html.unescape(question),
                'utf8': 1,
                'formatversion': 2,
                'srlimit': 1,
            }

            response = requests.get(url, params=params)
            response.raise_for_status()

            set_response(connection, id, response.json())

            logger.info(f'Got Answer for {id}')

        except Exception as e:
            tb = traceback.format_exc()
            error = f'{e}\n{tb}'
            logger.error(error)
            set_error(connection, id, error)

if __name__ == "__main__":
    main(search)
