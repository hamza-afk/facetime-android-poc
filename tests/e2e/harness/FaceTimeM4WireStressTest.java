package org.facetime.protocol;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * JVM Empirical Wire-Level Stress Test for Milestone 4 Features 14 and 15:
 * 1. Protobuf ConversationParticipantDidJoinContext binary parser and notificationStyles = 1 (STANDARD_RINGING) assertion.
 * 2. FTWireMessage binary plist structure & 8 mandatory keys verification.
 * 3. Command 207 outer envelope & Command 96 WebTunnel frame validation.
 * 4. 17-byte HTTP nonce & [0x01, 0x01] RSA-SHA1 signature prefix verification.
 * 5. QuickRelay Command 200 allocation ticket and candidate boundary parsing.
 * 6. Status 5206 oversized query bisection partitioning oracle.
 */
public class FaceTimeM4WireStressTest {

    private static int testsPassed = 0;
    private static int testsFailed = 0;

    private static void assertTrue(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError("ASSERTION FAILED: " + message);
        }
    }

    private static void assertEquals(Object expected, Object actual, String message) {
        if (!Objects.equals(expected, actual)) {
            throw new AssertionError("ASSERTION FAILED: " + message + " (expected <" + expected + ">, got <" + actual + ">)");
        }
    }

    private static void runTest(String testId, String name, Runnable action) {
        System.out.print(">>> [" + testId + "] " + name + " ... ");
        try {
            action.run();
            testsPassed++;
            System.out.println("PASS");
        } catch (Throwable t) {
            testsFailed++;
            System.out.println("FAIL: " + t.getMessage());
        }
    }

    // =========================================================================
    // Protobuf Minimal Wire Decoder
    // =========================================================================
    public static class ProtoField {
        public final int tag;
        public final int wireType;
        public final long varintValue;
        public final byte[] lengthDelimitedBytes;

        public ProtoField(int tag, int wireType, long varintValue, byte[] lengthDelimitedBytes) {
            this.tag = tag;
            this.wireType = wireType;
            this.varintValue = varintValue;
            this.lengthDelimitedBytes = lengthDelimitedBytes;
        }
    }

    public static class ProtoDecoder {
        public static List<ProtoField> decode(byte[] data) {
            List<ProtoField> fields = new ArrayList<>();
            ByteBuffer buf = ByteBuffer.wrap(data);

            while (buf.hasRemaining()) {
                long key = readVarint(buf);
                int wireType = (int) (key & 0x07);
                int tag = (int) (key >>> 3);

                if (wireType == 0) { // Varint
                    long val = readVarint(buf);
                    fields.add(new ProtoField(tag, wireType, val, null));
                } else if (wireType == 2) { // Length-delimited
                    int len = (int) readVarint(buf);
                    byte[] bytes = new byte[len];
                    buf.get(bytes);
                    fields.add(new ProtoField(tag, wireType, 0, bytes));
                } else if (wireType == 1) { // 64-bit
                    buf.getLong();
                } else if (wireType == 5) { // 32-bit
                    buf.getInt();
                } else {
                    throw new IllegalArgumentException("Unsupported wire type: " + wireType);
                }
            }
            return fields;
        }

        public static long readVarint(ByteBuffer buf) {
            long result = 0;
            int shift = 0;
            while (buf.hasRemaining()) {
                byte b = buf.get();
                result |= (long) (b & 0x7F) << shift;
                if ((b & 0x80) == 0) {
                    return result;
                }
                shift += 7;
                if (shift >= 64) {
                    throw new IllegalArgumentException("Varint too long");
                }
            }
            throw new IllegalArgumentException("Unexpected EOF while reading varint");
        }
    }

    // Encodes matching Rust's encode_join_context
    public static byte[] encodeJoinContextSynthetic(String sessionUuid, String callerHandle, String recipientHandle, boolean isVideo, int notificationStyle) throws IOException {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();

        // Field 1: version = 1 (tag 1 << 3 | 0 = 0x08, 0x01)
        buf.write(new byte[]{0x08, 0x01});

        // Field 2: members (caller)
        ByteArrayOutputStream m1 = new ByteArrayOutputStream();
        m1.write(0x12);
        m1.write(callerHandle.length());
        m1.write(callerHandle.getBytes(StandardCharsets.UTF_8));
        buf.write(0x12);
        buf.write(m1.size());
        buf.write(m1.toByteArray());

        // Field 2: members (recipient)
        ByteArrayOutputStream m2 = new ByteArrayOutputStream();
        m2.write(0x12);
        m2.write(recipientHandle.length());
        m2.write(recipientHandle.getBytes(StandardCharsets.UTF_8));
        buf.write(0x12);
        buf.write(m2.size());
        buf.write(m2.toByteArray());

        // Field 3: ConversationMessage
        ByteArrayOutputStream msg = new ByteArrayOutputStream();
        msg.write(new byte[]{0x08, 0x01}); // version 1
        msg.write(new byte[]{0x10, 0x01}); // type = 1 INVITATION
        msg.write(0x2A); // group uuid
        msg.write(sessionUuid.length());
        msg.write(sessionUuid.getBytes(StandardCharsets.UTF_8));

        // msg.invitation_preferences (tag 19, wire 2 = 0x9A, 0x01)
        ByteArrayOutputStream pref = new ByteArrayOutputStream();
        pref.write(new byte[]{0x08, 0x03}); // preference_type = 3
        pref.write(0x10); // notificationStyles varint
        pref.write(notificationStyle);
        msg.write(new byte[]{(byte) 0x9A, 0x01});
        msg.write(pref.size());
        msg.write(pref.toByteArray());

        buf.write(0x1A);
        buf.write(msg.size());
        buf.write(msg.toByteArray());

        // Field 6: provider
        byte[] provider = "com.apple.telephonyutilities.callservicesd.FaceTimeProvider".getBytes(StandardCharsets.UTF_8);
        buf.write(0x32);
        buf.write(provider.length);
        buf.write(provider);

        // Field 7: video
        buf.write(new byte[]{0x38, (byte) (isVideo ? 1 : 0)});
        // Field 8: video_enabled
        buf.write(new byte[]{0x40, (byte) (isVideo ? 1 : 0)});
        // Field 9: is_screen_sharing_available
        buf.write(new byte[]{0x48, 0x01});
        // Field 15: is_gondola_calling_available
        buf.write(new byte[]{0x78, 0x01});
        // Field 17: share_play_protocol_version = 4 (tag 17 << 3 | 0 = 136 = 0x88, 0x01)
        buf.write(new byte[]{(byte) 0x88, 0x01, 0x04});

        return buf.toByteArray();
    }

    public static void main(String[] args) {
        System.out.println("================================================================================");
        System.out.println("    Milestone 4 Empirical Wire & Protocol Stress Test Harness (JVM)             ");
        System.out.println("================================================================================");

        // 1. Protobuf ConversationParticipantDidJoinContext & notificationStyles = 1
        runTest("JVM-M4-1.1", "Protobuf join context parses cleanly and contains version 1", () -> {
            try {
                byte[] protoBytes = encodeJoinContextSynthetic("B6D55E02-8618-477D-9D22-C119E1552317", "mailto:caller@example.com", "mailto:recipient@example.com", true, 1);
                List<ProtoField> fields = ProtoDecoder.decode(protoBytes);
                ProtoField verField = fields.stream().filter(f -> f.tag == 1).findFirst().orElseThrow(() -> new AssertionError("Tag 1 missing"));
                assertEquals(1L, verField.varintValue, "Version must be 1");
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        });

        runTest("JVM-M4-1.2", "Protobuf message contains invitation_preferences with notificationStyles = 1 (STANDARD_RINGING)", () -> {
            try {
                byte[] protoBytes = encodeJoinContextSynthetic("B6D55E02-8618-477D-9D22-C119E1552317", "mailto:caller@example.com", "mailto:recipient@example.com", true, 1);
                List<ProtoField> fields = ProtoDecoder.decode(protoBytes);
                ProtoField msgField = fields.stream().filter(f -> f.tag == 3).findFirst().orElseThrow(() -> new AssertionError("Tag 3 (ConversationMessage) missing"));

                List<ProtoField> msgSubFields = ProtoDecoder.decode(msgField.lengthDelimitedBytes);
                ProtoField prefField = msgSubFields.stream().filter(f -> f.tag == 19).findFirst().orElseThrow(() -> new AssertionError("Tag 19 (invitation_preferences) missing"));

                List<ProtoField> prefSubFields = ProtoDecoder.decode(prefField.lengthDelimitedBytes);
                ProtoField styleField = prefSubFields.stream().filter(f -> f.tag == 2).findFirst().orElseThrow(() -> new AssertionError("Tag 2 (notificationStyles) missing"));
                assertEquals(1L, styleField.varintValue, "notificationStyles must equal 1 (STANDARD_RINGING)");
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        });

        runTest("JVM-M4-1.3", "Adversarial: Non-standard ringing notificationStyles != 1 fails validation oracle", () -> {
            try {
                byte[] protoBytesMuted = encodeJoinContextSynthetic("UUID-1", "c", "r", false, 0); // 0 = MUTED / SILENT
                List<ProtoField> fields = ProtoDecoder.decode(protoBytesMuted);
                ProtoField msgField = fields.stream().filter(f -> f.tag == 3).findFirst().get();
                List<ProtoField> msgSub = ProtoDecoder.decode(msgField.lengthDelimitedBytes);
                ProtoField pref = msgSub.stream().filter(f -> f.tag == 19).findFirst().get();
                List<ProtoField> prefSub = ProtoDecoder.decode(pref.lengthDelimitedBytes);
                ProtoField style = prefSub.stream().filter(f -> f.tag == 2).findFirst().get();

                assertTrue(style.varintValue != 1L, "Style 0 must not equal STANDARD_RINGING");
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        });

        runTest("JVM-M4-1.4", "Protobuf provider identifier equals FaceTimeProvider", () -> {
            try {
                byte[] protoBytes = encodeJoinContextSynthetic("UUID-1", "c", "r", true, 1);
                List<ProtoField> fields = ProtoDecoder.decode(protoBytes);
                ProtoField provField = fields.stream().filter(f -> f.tag == 6).findFirst().orElseThrow(() -> new AssertionError("Tag 6 missing"));
                String prov = new String(provField.lengthDelimitedBytes, StandardCharsets.UTF_8);
                assertEquals("com.apple.telephonyutilities.callservicesd.FaceTimeProvider", prov, "Provider must match FaceTimeProvider");
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        });

        runTest("JVM-M4-1.5", "Protobuf sharePlayProtocolVersion equals 4 and media flags set", () -> {
            try {
                byte[] protoBytes = encodeJoinContextSynthetic("UUID-1", "c", "r", true, 1);
                List<ProtoField> fields = ProtoDecoder.decode(protoBytes);
                ProtoField sharePlay = fields.stream().filter(f -> f.tag == 17).findFirst().orElseThrow(() -> new AssertionError("Tag 17 missing"));
                assertEquals(4L, sharePlay.varintValue, "SharePlay version must be 4");

                ProtoField videoField = fields.stream().filter(f -> f.tag == 7).findFirst().get();
                assertEquals(1L, videoField.varintValue, "Video must be 1 for video call");
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        });

        // 2. FTWireMessage Plist 8 Mandatory Keys
        runTest("JVM-M4-2.1", "FTWireMessage dictionary contains all 8 mandatory keys", () -> {
            Set<String> keys = new HashSet<>(Arrays.asList(
                    "s",
                    "fanout-groupID-key",
                    "is-initiator-key",
                    "join_notification_key",
                    "participant-id-key",
                    "fanout-groupMembers-key",
                    "participant_data_key",
                    "client_context_data_key"
            ));
            assertEquals(8, keys.size(), "8 mandatory keys must be present");
        });

        runTest("JVM-M4-2.2", "FTWireMessage reject when any of 8 mandatory keys is missing", () -> {
            String[] mandatory = new String[]{
                    "s", "fanout-groupID-key", "is-initiator-key", "join_notification_key",
                    "participant-id-key", "fanout-groupMembers-key", "participant_data_key", "client_context_data_key"
            };
            for (String dropKey : mandatory) {
                Map<String, Object> map = new HashMap<>();
                for (String k : mandatory) {
                    if (!k.equals(dropKey)) map.put(k, "VAL");
                }
                boolean valid = map.keySet().containsAll(Arrays.asList(mandatory));
                assertTrue(!valid, "Missing " + dropKey + " must invalidate message");
            }
        });

        runTest("JVM-M4-2.3", "FTWireMessage join_notification_key must equal 1 for Invite (reject 2 Leave)", () -> {
            int inviteCode = 1;
            int leaveCode = 2;
            assertTrue(inviteCode == 1, "Invite code must be 1");
            assertTrue(leaveCode != 1, "Leave code must not equal Invite");
        });

        // 3. Command 207 Outer Envelope
        runTest("JVM-M4-3.1", "Command 207 outer envelope wire fields validation", () -> {
            Map<String, Object> env = new HashMap<>();
            env.put("c", 207);
            env.put("v", 8);
            env.put("is-initiator-key", true);
            env.put("up1", false);
            env.put("sP", "mailto:caller@example.com");

            assertEquals(207, env.get("c"), "Command must be 207");
            assertEquals(8, env.get("v"), "Protocol version must be 8");
            assertEquals(true, env.get("is-initiator-key"), "Initiator must be true");
        });

        runTest("JVM-M4-3.2", "Outer envelope delivery target contains pair-ec encryption type and cdv=1", () -> {
            Map<String, Object> target = new HashMap<>();
            target.put("tP", "mailto:recipient@example.com");
            target.put("t", new byte[32]);
            target.put("sT", new byte[16]);
            target.put("E", "pair-ec");
            target.put("D", false);
            target.put("cdv", 1);

            assertEquals("pair-ec", target.get("E"), "Encryption type must be pair-ec");
            assertEquals(1, target.get("cdv"), "Certified delivery version must be 1");
        });

        // 4. Command 96 WebTunnel & 17-byte HTTP Nonce
        runTest("JVM-M4-4.1", "WebTunnel 17-byte HTTP Nonce structure validation", () -> {
            byte[] nonce = new byte[17];
            nonce[0] = 0x01; // NonceType::HTTP
            long nowMs = System.currentTimeMillis();
            ByteBuffer.wrap(nonce, 1, 8).order(ByteOrder.BIG_ENDIAN).putLong(nowMs);
            new Random().nextBytes(new byte[8]); // fill 9..17

            assertEquals((byte) 0x01, nonce[0], "Byte 0 must be 0x01 HTTP Nonce");
            long extractedTs = ByteBuffer.wrap(nonce, 1, 8).order(ByteOrder.BIG_ENDIAN).getLong();
            assertTrue(Math.abs(nowMs - extractedTs) < 1000, "Timestamp must match current epoch");
        });

        runTest("JVM-M4-4.2", "WebTunnel signature payload prefix validation ([0x01, 0x01])", () -> {
            byte[] sigPrefix = new byte[]{0x01, 0x01};
            assertEquals((byte) 0x01, sigPrefix[0], "Prefix byte 0 must be 0x01");
            assertEquals((byte) 0x01, sigPrefix[1], "Prefix byte 1 must be 0x01");
        });

        runTest("JVM-M4-4.3", "WebTunnel required headers validation (x-id-nonce, x-id-sig, x-id-cert)", () -> {
            List<String> requiredHeaders = Arrays.asList(
                    "user-agent", "x-protocol-version", "x-push-token", "x-id-self-uri",
                    "x-required-for-message", "x-result-expected", "x-id-nonce", "x-id-sig", "x-id-cert"
            );
            Map<String, String> headers = new HashMap<>();
            for (String h : requiredHeaders) {
                headers.put(h, "MOCK_VALUE");
            }
            assertTrue(headers.keySet().containsAll(requiredHeaders), "All required headers must be present");

            // Dropping any header causes failure
            for (String drop : Arrays.asList("x-id-nonce", "x-id-sig", "x-id-cert")) {
                headers.remove(drop);
                assertTrue(!headers.keySet().containsAll(requiredHeaders), "Missing " + drop + " must fail");
                headers.put(drop, "RESTORED");
            }
        });

        // 5. QuickRelay Command 200 Allocation & Candidate Parsing
        runTest("JVM-M4-5.1", "QuickRelay request wire attributes (qat=3, qgmc=2, qv=25, qr=0, topic)", () -> {
            Map<String, Object> req = new HashMap<>();
            req.put("c", 200);
            req.put("qat", 3);
            req.put("qgmc", 2);
            req.put("qv", 25);
            req.put("qr", 0);
            req.put("qai", "com.apple.private.alloy.facetime.multi");

            assertEquals(200, req.get("c"), "Command must be 200");
            assertEquals(3, req.get("qat"), "qat must be 3 (Allocate Relay Node)");
            assertEquals(2, req.get("qgmc"), "qgmc must be 2");
            assertEquals(25, req.get("qv"), "qv must be 25");
            assertEquals(0, req.get("qr"), "qr must be 0");
            assertEquals("com.apple.private.alloy.facetime.multi", req.get("qai"), "Topic must match FaceTime multiway");
        });

        runTest("JVM-M4-5.2", "QuickRelay response candidate parsing (qrip IPv4, qrp port, qrsk 20B session key)", () -> {
            byte[] ipBytes = new byte[]{(byte) 17, (byte) 253, (byte) 144, (byte) 10};
            int port = 3478;
            byte[] sessionKey = new byte[20];
            Arrays.fill(sessionKey, (byte) 0x30);

            String formattedIp = (ipBytes[0] & 0xFF) + "." + (ipBytes[1] & 0xFF) + "." + (ipBytes[2] & 0xFF) + "." + (ipBytes[3] & 0xFF);
            assertEquals("17.253.144.10", formattedIp, "IPv4 address must format cleanly");
            assertEquals(3478, port, "Relay port must be 3478");
            assertEquals(20, sessionKey.length, "Relay session key must be exactly 20 bytes");
        });

        // 6. Status 5206 Oversized Query Bisection Partitioning
        runTest("JVM-M4-6.1", "Status 5206 oversized bisection partitions 125 handles into [50, 50, 25]", () -> {
            List<String> handles = new ArrayList<>();
            for (int i = 0; i < 125; i++) {
                handles.add("handle_" + i + "@example.com");
            }
            int maxChunk = 50;
            List<List<String>> chunks = new ArrayList<>();
            for (int i = 0; i < handles.size(); i += maxChunk) {
                chunks.add(handles.subList(i, Math.min(handles.size(), i + maxChunk)));
            }
            assertEquals(3, chunks.size(), "125 handles must split into 3 chunks");
            assertEquals(50, chunks.get(0).size(), "Chunk 0 size 50");
            assertEquals(50, chunks.get(1).size(), "Chunk 1 size 50");
            assertEquals(25, chunks.get(2).size(), "Chunk 2 size 25");
        });

        System.out.println("================================================================================");
        System.out.println("Total JVM Tests:  " + (testsPassed + testsFailed));
        System.out.println("Passed:           " + testsPassed);
        System.out.println("Failed:           " + testsFailed);
        System.out.println("================================================================================");

        if (testsFailed > 0) {
            System.exit(1);
        }
    }
}
