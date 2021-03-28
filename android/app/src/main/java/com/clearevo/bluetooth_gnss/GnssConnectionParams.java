package com.clearevo.bluetooth_gnss;

import java.util.HashMap;
import java.util.Map;

import lombok.Getter;
import lombok.Setter;
import lombok.ToString;

@Getter
@Setter
@ToString
public class GnssConnectionParams {
    private String bdaddr;
    private boolean secure;
    private boolean reconnect;
    private boolean logBtRx;
    private boolean disableNtrip;
    private final Map<String, String> extraParams = new HashMap<>();
}
