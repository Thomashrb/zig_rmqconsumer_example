const std = @import("std");
const c = @cImport({
    @cInclude("amqp.h");
    @cInclude("amqp_tcp_socket.h");
    @cInclude("amqp_framing.h");
});

const HOSTNAME: [*]const u8 = "localhost";
const VHOST: [*]const u8 = "Some_Virtual_Host";
const PORT: isize = 5672;
const USERNAME: [*]const u8 = "testuser";
const PASSWORD: [*]const u8 = "testpassword";

const EXCHANGE: [*]const u8 = "some_exchange";
const QUEUE_NAME: [*]const u8 = "some_outgoing_queue";
const BINDING_KEY: [*]const u8 = "some_routing_key";
const CONSUMER_TAG: [*]const u8 = "testuser";

fn handle(conn: c.amqp_connection_state_t) void {
    var envelope: c.amqp_envelope_t = undefined;
    defer _ = c.amqp_destroy_envelope(&envelope);

    while (true) {
        var retm = c.amqp_consume_message(conn, &envelope, null, 0);
        if (c.AMQP_RESPONSE_NORMAL != retm.reply_type) {
            break;
        }
        const message: c.amqp_bytes_t = envelope.message.body;
        var str: []const u8 = @ptrCast([*]u8, message.bytes.?)[0..message.len];
        std.debug.print("\n Message: {s}\n", .{str});
    }
}

pub fn main() !void {
    var conn: c.amqp_connection_state_t = c.amqp_new_connection().?;
    defer _ = c.amqp_channel_close(conn, 1, c.AMQP_REPLY_SUCCESS);
    defer _ = c.amqp_connection_close(conn, c.AMQP_REPLY_SUCCESS);
    errdefer _ = c.amqp_destroy_connection(conn);
    const socket: ?*c.amqp_socket_t = c.amqp_tcp_socket_new(conn);
    const status: isize = c.amqp_socket_open(socket, HOSTNAME, PORT);

    if (status != 0) {
        std.debug.print("Could not open socket to rmq. Status: {d}", .{status});
    }

    _ = c.amqp_login(conn, VHOST, 200, 131072, 0, c.AMQP_SASL_METHOD_PLAIN, USERNAME, PASSWORD);
    _ = c.amqp_channel_open(conn, 1);
    _ = c.amqp_queue_bind(conn, 1, c.amqp_cstring_bytes(QUEUE_NAME), c.amqp_cstring_bytes(EXCHANGE), c.amqp_cstring_bytes(BINDING_KEY), c.amqp_empty_table);
    _ = c.amqp_basic_consume(conn, 1, c.amqp_cstring_bytes(QUEUE_NAME), c.amqp_cstring_bytes(CONSUMER_TAG), 0, 1, 0, c.amqp_empty_table);

    _ = handle(conn);
}
