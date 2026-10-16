package org.facetime.diagnostic;

import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.regex.*;

/**
 * JVM Adversarial Empirical Test for SecretSanitizer on Call Diagnostic Secrets.
 * Tests SecretSanitizer against call-related tokens:
 * - Push Tokens (caller / recipient APNS tokens)
 * - Session Keys (QuickRelay qrsk, session_key, sessionKey)
 * - Tickets (QuickRelay qrst, relayTicket, ticket, sessionToken)
 */
public class CallSecretSanitizerJvmStressTest {

    // Import exact rules from SecretSanitizerJvmStressTest / SecretSanitizer.kt
    public static final List<SecretSanitizerJvmStressTest.RedactionRule> RULES = SecretSanitizerJvmStressTest.RULES;

    public static String sanitize(String input) {
        String current = input;
        AtomicInteger counter = new AtomicInteger(0);
        for (SecretSanitizerJvmStressTest.RedactionRule rule : RULES) {
            current = rule.apply(current, SecretSanitizerJvmStressTest.RedactionStyle.SQUARE_BRACKETS, counter);
        }
        return current;
    }

    public static void main(String[] args) {
        System.out.println("================================================================================");
        System.out.println("   CallSecretSanitizer JVM Adversarial Audit -- Challenger M4-2                 ");
        System.out.println("================================================================================");

        int passed = 0;
        int failed = 0;

        // 1. Test SessionToken (Already covered by GENERIC_AUTH_TOKEN rule)
        String sessionTokenJson = "{\"sessionToken\":\"abcdef0123456789abcdef0123456789\"}";
        String outSessionToken = sanitize(sessionTokenJson);
        if (!outSessionToken.contains("abcdef0123456789abcdef0123456789") && outSessionToken.contains("[REDACTED_AUTH_TOKEN]")) {
            System.out.println("  [PASS] sessionToken is properly sanitized by GENERIC_AUTH_TOKEN rule");
            passed++;
        } else {
            System.out.println("  [FAIL] sessionToken leaked: " + outSessionToken);
            failed++;
        }

        // 2. Audit Push Tokens (e.g. 64-char hex APNS token)
        String pushTokenSecret = "5aF7k90123456789abcdef0123456789abcdef0123456789abcdef0123456789";
        String pushTokenJson = "{\"action\":\"CALL_INIT\",\"recipient_push_token\":\"" + pushTokenSecret + "\"}";
        String outPushToken = sanitize(pushTokenJson);
        boolean pushTokenLeaked = outPushToken.contains(pushTokenSecret);
        if (pushTokenLeaked) {
            System.out.println("  [FINDING / LEAK DETECTED] recipient_push_token is NOT sanitized by SecretSanitizer!");
            System.out.println("    Raw input:  " + pushTokenJson);
            System.out.println("    Sanitized:  " + outPushToken);
            failed++;
        } else {
            System.out.println("  [PASS] recipient_push_token is sanitized");
            passed++;
        }

        // 3. Audit QuickRelay Session Key (qrsk / session_key)
        String sessionKeySecret = "fedcba9876543210fedcba9876543210";
        String sessionKeyJson = "{\"event\":\"RELAY_ALLOCATED\",\"qrsk\":\"" + sessionKeySecret + "\",\"session_key\":\"" + sessionKeySecret + "\"}";
        String outSessionKey = sanitize(sessionKeyJson);
        boolean sessionKeyLeaked = outSessionKey.contains(sessionKeySecret);
        if (sessionKeyLeaked) {
            System.out.println("  [FINDING / LEAK DETECTED] QuickRelay session keys (qrsk / session_key) are NOT sanitized!");
            System.out.println("    Raw input:  " + sessionKeyJson);
            System.out.println("    Sanitized:  " + outSessionKey);
            failed++;
        } else {
            System.out.println("  [PASS] session keys are sanitized");
            passed++;
        }

        // 4. Audit QuickRelay Tickets (qrst / relayTicket)
        String ticketSecret = "QR_TICKET_RELAY_SESSION_DATA_998877";
        String ticketJson = "{\"qrst\":\"" + ticketSecret + "\",\"relayTicket\":\"" + ticketSecret + "\"}";
        String outTicket = sanitize(ticketJson);
        boolean ticketLeaked = outTicket.contains(ticketSecret);
        if (ticketLeaked) {
            System.out.println("  [FINDING / LEAK DETECTED] QuickRelay tickets (qrst / relayTicket) are NOT sanitized!");
            System.out.println("    Raw input:  " + ticketJson);
            System.out.println("    Sanitized:  " + outTicket);
            failed++;
        } else {
            System.out.println("  [PASS] QuickRelay tickets are sanitized");
            passed++;
        }

        System.out.println("================================================================================");
        System.out.printf("Call Secret Redaction Audit: Passed=%d, Findings/Leaks=%d%n", passed, failed);
        System.out.println("================================================================================");

        // Exit with count of leaks so runner can record empirical observations
        System.exit(failed);
    }
}
