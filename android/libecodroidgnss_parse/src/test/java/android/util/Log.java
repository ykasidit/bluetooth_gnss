package android.util;

//from https://stackoverflow.com/questions/36787449/how-to-mock-method-e-in-log

public class Log {
    public static String getStackTraceString(Throwable ex) {
        StringBuilder retb = new StringBuilder(ex.toString()+": stack_trace:\n");
        for (StackTraceElement t : ex.getStackTrace()) {
            retb.append("\tat "+t.toString()+"\n");
        }
        return retb.toString();
    }

    public static int d(String tag, String msg) {
        System.out.println("DEBUG: " + tag + ": " + msg);
        return 0;
    }

    public static int i(String tag, String msg) {
        System.out.println("INFO: " + tag + ": " + msg);
        return 0;
    }

    public static int w(String tag, String msg) {
        System.out.println("WARN: " + tag + ": " + msg);
        return 0;
    }

    public static int e(String tag, String msg) {
        System.out.println("ERROR: " + tag + ": " + msg);
        return 0;
    }

    // add other methods if required...
}
