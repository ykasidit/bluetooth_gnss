package com.clearevo.libbluetooth_gnss_service;

import android.content.Context;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.util.Log;

public class RealLocationHelper {

    public static void getRealLocation(Context context, LocationCallback callback) {
        LocationManager locationManager = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);

        if (locationManager == null) {
            callback.onLocationError("LocationManager is null");
            return;
        }

        if (!locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            callback.onLocationError("GPS provider is not enabled");
            return;
        }

        try {
            locationManager.requestSingleUpdate(LocationManager.GPS_PROVIDER, new LocationListener() {
                @Override
                public void onLocationChanged(Location location) {
                    if (location != null && !location.isFromMockProvider()) {
                        callback.onLocationReceived(location);
                    } else {
                        callback.onLocationError("Location is from mock provider or null");
                    }
                }

                @Override public void onStatusChanged(String provider, int status, Bundle extras) {}
                @Override public void onProviderEnabled(String provider) {}
                @Override public void onProviderDisabled(String provider) {}
            }, null);
        } catch (SecurityException e) {
            callback.onLocationError("Permission denied: " + e.getMessage());
        }
    }

    public interface LocationCallback {
        void onLocationReceived(Location location);
        void onLocationError(String message);
    }
}
