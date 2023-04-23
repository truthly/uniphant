use postgres::{Client, NoTls};
use std::convert::TryInto;
use std::option::Option;
use uuid::Uuid;

pub fn connect() -> Client {
    let connection = Client::connect("host=localhost user=joel", NoTls)
        .expect("Failed to connect to the database");
    connection
}

pub fn delete_process(connection: &mut Client, process_id: Uuid) -> () {
    connection
        .execute("SELECT delete_process($1)", &[&process_id])
        .expect("Failed to execute delete_process");
}

pub fn keepalive(connection: &mut Client, process_id: Uuid) -> bool {
    let rows = connection
        .query("SELECT keepalive($1)", &[&process_id])
        .expect("Failed to execute keepalive");
    rows.get(0).unwrap().get(0)
}

pub fn register_process(connection: &mut Client, process_id: Uuid, worker_id: Uuid, pid: i32) -> () {
    connection
        .execute(
            "SELECT register_process($1, $2, $3)",
            &[&process_id, &worker_id, &pid],
        )
        .expect("Failed to execute register_process");
}

pub fn register_host(connection: &mut Client, host_id: Uuid, host_name: &str) -> () {
    connection
        .execute(
            "SELECT register_host($1, $2)",
            &[&host_id, &host_name],
        )
        .expect("Failed to execute register_host");
}

pub fn get_existing_process_info(
    connection: &mut Client,
    host_id: Uuid,
    worker_id: Uuid,
) -> Option<(Uuid, u32)> {
    let rows = connection
        .query(
            "SELECT process_id, pid FROM get_existing_process_info($1, $2)",
            &[&host_id, &worker_id],
        )
        .expect("Failed to execute get_existing_process_info");

    let row = rows.iter().next().unwrap();
    let process_id: Option<Uuid> = row.get("process_id");

    match process_id {
        Some(id) => {
            let pid: i32 = row.get("pid");
            let pid_u32: u32 = pid.try_into().unwrap();
            Some((id, pid_u32))
        },
        None => None,
    }
}
