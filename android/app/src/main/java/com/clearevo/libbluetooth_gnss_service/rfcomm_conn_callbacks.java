package com.clearevo.libbluetooth_gnss_service;


import org.json.JSONObject;

public interface rfcomm_conn_callbacks extends tcp_server_client_callbacks {
    public void on_rfcomm_connected();
    public void on_rfcomm_disconnected();
    public void on_read_object(JSONObject object);
}
