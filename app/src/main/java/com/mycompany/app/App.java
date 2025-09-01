package com.mycompany.app;

/**
 * Hello world demo application.
 */
public final class App {

    /** Greeting message printed by the app. */
    private static final String MESSAGE = "Hello World!";

    /** Default constructor. */
    public App() { }

    /**
     * Application entry point.
     *
     * @param args command-line arguments (unused)
     */
    public static void main(final String[] args) {
        System.out.println(MESSAGE);
    }

    /**
     * Returns greeting message.
     *
     * @return greeting text
     */
    public String getMessage() {
        return MESSAGE;
    }
}
