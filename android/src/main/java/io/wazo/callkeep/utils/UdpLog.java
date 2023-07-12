package io.wazo.callkeep.utils;

import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.Message;
import android.util.Log;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;

public class UdpLog {

    private static final boolean ENABLED = false; // Flag, edit to enable/disable the logger.
    private static final String HOST = "192.168.88.17";
    private static final int PORT = 64000;

    private static UdpLog _instance = null;
    private static final String TAG = "RNCK:UdpLog";
    private static class UdpLogHandler extends Handler {
        private final DatagramSocket _udpSocket;
        private final InetAddress _host;
        public UdpLogHandler(Looper looper) throws Exception {
            super(looper);
            _udpSocket = new DatagramSocket();
            _host = InetAddress.getByName(HOST);
        }

        @Override
        protected void finalize() throws Throwable {
            if (_udpSocket != null) {
                _udpSocket.close();
            }

            super.finalize();
        }

        public void handleMessage(Message msg) {
            try
            {
                String message = (String) msg.obj;
                byte[] sendBuffer = (message + "\n").getBytes();
                _udpSocket.send(new DatagramPacket(sendBuffer, sendBuffer.length, _host, PORT));
            }
            catch(Exception e)
            {
                Log.e(TAG, "Can't send UDP message.", e);
            }
        }
    }


    private UdpLogHandler _handler;

    private UdpLog() {
        try {
            HandlerThread handlerThread = new HandlerThread("UdpLog Thread");
            handlerThread.start();
            _handler = new UdpLogHandler(handlerThread.getLooper());
        } catch (Exception e) {
            Log.e(TAG, "Can't initialize UdpLog.", e);
        }
    }

    public static void send(String logMessage) {
        if (!ENABLED) {
            Log.d(TAG, "Logger isn't enabled, skip message: " + logMessage);
            return;
        }

        if (_instance == null) {
            _instance = new UdpLog();
        }

        Message msg = _instance._handler.obtainMessage();
        msg.obj = logMessage;
        _instance._handler.sendMessage(msg);
    }
}
