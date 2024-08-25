package com.clearevo.bluetooth_gnss;

import java.util.HashMap;
import java.util.Map;

public class GnssConnectionParams {
    public String bdaddr;
    public boolean secure;
    public boolean reconnect;
    public boolean logBtRx;
    public boolean disableNtrip;
    public boolean gapMode;
    public boolean ble_qstarz_mode;
    public boolean ble_uart_mode;
    public final Map<String, String> extraParams = new HashMap<>();
}
