package com.clearevo.bluetooth_gnss;

import java.io.Serializable;
import java.util.HashMap;
import java.util.Map;

public class GnssConnectionParams implements Serializable {
    public String bdaddr;
    public boolean secure;
    public boolean reconnect;
    public String  log_bt_rx_log_uri;
    public boolean disableNtrip;
    public boolean gapMode;
    public boolean ble_qstarz_mode;
    public boolean ble_uart_mode;
    public boolean autostart;
    public final Map<String, String> extraParams = new HashMap<>();
}
