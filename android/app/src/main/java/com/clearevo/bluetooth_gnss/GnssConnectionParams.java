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
    public String bdaddr;
    public boolean secure;
    public boolean reconnect;
    public boolean logBtRx;
    public boolean disableNtrip;
    public boolean gapMode;
    public final Map<String, String> extraParams = new HashMap<>();
}
