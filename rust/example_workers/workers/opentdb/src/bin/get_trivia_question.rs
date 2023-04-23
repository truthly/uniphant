use reqwest;
use log::{error, info};
use postgres::Client;
use uuid::Uuid;
use postgres::Error as PgError;

use uniphant::worker_context::WorkerContext;
use uniphant::worker::worker;

fn next(connection: &mut Client, process_id: Uuid) -> Result<Option<Uuid>, PgError> {
    let stmt = "
        SELECT opentdb.get_trivia_question_next($1)
    ";

    let result = connection.query_opt(stmt, &[&process_id])?;

    match result {
        Some(row) => Ok(row.get(0)),
        None => Ok(None),
    }
}

fn set_response(connection: &mut Client, id: Uuid, response: serde_json::Value) -> Result<(), PgError> {
    let stmt = "
        SELECT opentdb.get_trivia_question_set_response($1, $2)
    ";

    connection.execute(stmt, &[&id, &response])?;
    Ok(())
}

fn set_error(connection: &mut Client, id: Uuid, error: &str) -> Result<(), PgError> {
    let stmt = "
        SELECT opentdb.get_trivia_question_set_error($1, $2)
    ";

    connection.execute(stmt, &[&id, &error])?;
    Ok(())
}

fn get_trivia_question(
    connection: &mut Client,
    _config: &std::collections::HashMap<String, String>,
    context: &WorkerContext,
) -> Result<(), Box<dyn std::error::Error>> {
    loop {
        match next(connection, context.process_id) {
            Ok(Some(id)) => {
                info!("Getting Question for {}", id);

                let url = "https://opentdb.com/api.php?amount=1";

                match reqwest::blocking::get(url) {
                    Ok(response) => {
                        match response.error_for_status() {
                            Ok(valid_response) => {
                                let json_response: serde_json::Value = valid_response.json()?;
                                set_response(connection, id, json_response)?;
                                info!("Got Question for {}", id);
                            }
                            Err(status_err) => {
                                error!("Request failed with error: {}", status_err);
                                set_error(connection, id, &status_err.to_string())?;
                            }
                        }
                    }
                    Err(request_err) => {
                        error!("Request failed with error: {}", request_err);
                        set_error(connection, id, &request_err.to_string())?;
                    }
                }

            }
            Ok(None) => {
                break;
            }
            Err(e) => {
                error!("Error retrieving next question: {}", e);
            }
        }
    }

    Ok(())
}

fn main() {
    worker(get_trivia_question);
}
