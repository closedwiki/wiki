package CH.ifa.draw.appframe;

import java.net.URL;
import java.net.MalformedURLException;
import java.io.IOException;
import java.io.InputStream;

/**
 * Interface to controlling application, either an applet or a java
 * application. Makes a DrawFrame independent of it's context.
 */
public interface Application {
    /** Show status string, eg in applet area */
    void showStatus(String s);
    /** Get command-line or applet parameter */
    String getParameter(String name);
    /** Get URL relative to the codebase of the app */
    InputStream getStream(String relURL) throws IOException;
    /** Popup a URL in a new frame */
    void popupFrame(String url, String title);
    /** exit the application (applet or whatever) */
    void exit();
    boolean post(String url,
                 String fileName,
                 String cryptToken,
                 String type,
                 String path,
                 String content,
                 String comment) throws IOException;
}
