use postgres::{Client, NoTls, Config};
use std::option::Option;
use uuid::Uuid;

pub fn database_config(
    dbname: Option<&str>,
    user: Option<&str>,
    password: Option<&str>,
    host: Option<&str>,
    port: Option<u16>,
) -> Config {
    let mut config = Config::new();
    if let Some(dbname) = dbname {
        config.dbname(dbname);
    }
    if let Some(user) = user {
        config.user(user);
    }
    if let Some(password) = password {
        config.password(password);
    }
    if let Some(host) = host {
        config.host(host);
    }
    if let Some(port) = port {
        config.port(port);
    }
    config
}

pub fn connect(dbconfig: Config) -> Client {
    let connection = dbconfig.connect(NoTls)
        .expect("Failed to connect to the database");
    connection
}

pub fn register_host(connection: &mut Client, host_id: Uuid, host_name: &str) -> () {
    connection
        .execute(
            "SELECT register_host($1, $2)",
            &[&host_id, &host_name],
        )
        .expect("Failed to execute register_host");
}

pub fn register_process(connection: &mut Client, process_id: Uuid, worker_id: Uuid, pid: i32) -> () {
    connection
        .execute(
            "SELECT register_process($1, $2, $3)",
            &[&process_id, &worker_id, &pid],
        )
        .expect("Failed to execute register_process");
}

pub fn keepalive(connection: &mut Client, process_id: Uuid) -> bool {
    let rows = connection
        .query("SELECT keepalive($1)", &[&process_id])
        .expect("Failed to execute keepalive");
    rows.get(0).unwrap().get(0)
}

pub fn delete_process(connection: &mut Client, process_id: Uuid) -> () {
    connection
        .execute("SELECT delete_process($1)", &[&process_id])
        .expect("Failed to execute delete_process");
}

pub fn get_worker_process_id(connection: &mut Client, worker_id: Uuid) -> Option<Uuid> {
    let rows = connection
        .query("SELECT get_worker_process_id($1)", &[&worker_id])
        .expect("Failed to execute get_worker_process_id");
    rows.get(0).unwrap().get(0)
}

pub fn request_process_termination(connection: &mut Client, process_id: Uuid) -> () {
    connection
        .execute(
            "SELECT request_process_termination($1)",
            &[&process_id],
        )
        .expect("Failed to execute request_process_termination");
}
