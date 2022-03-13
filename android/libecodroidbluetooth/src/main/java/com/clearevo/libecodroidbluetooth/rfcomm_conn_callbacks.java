package com.clearevo.libecodroidbluetooth;


public interface rfcomm_conn_callbacks extends readline_callbacks, tcp_server_client_callbacks {
    public void on_rfcomm_connected();
    public void on_rfcomm_disconnected();
}
