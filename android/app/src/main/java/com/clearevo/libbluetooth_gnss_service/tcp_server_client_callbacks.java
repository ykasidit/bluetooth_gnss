package com.clearevo.libbluetooth_gnss_service;

public interface tcp_server_client_callbacks {
    //for tcp server mode
    public void on_target_tcp_connected();
    public void on_target_tcp_disconnected();
}
