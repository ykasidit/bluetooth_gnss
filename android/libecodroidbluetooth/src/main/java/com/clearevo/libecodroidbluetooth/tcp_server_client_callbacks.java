package com.clearevo.libecodroidbluetooth;

public interface tcp_server_client_callbacks {
    //for tcp server mode
    public void on_target_tcp_connected();
    public void on_target_tcp_disconnected();
}
