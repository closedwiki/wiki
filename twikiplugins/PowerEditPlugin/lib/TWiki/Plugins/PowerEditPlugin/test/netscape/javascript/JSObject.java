package netscape.javascript;

import java.applet.Applet;
import java.util.Hashtable;

public final class JSObject extends Hashtable {
    private static JSObject window = null;

    public JSObject() {
    }

    public Object getMember(String m) {
	return get(m);
    }

    public static JSObject getWindow(Applet a) {
	return window;
    }

    public static void setWindow(JSObject w) {
	window = w;
    }
}
