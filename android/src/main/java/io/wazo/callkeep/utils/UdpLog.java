package io.wazo.callkeep.utils;

import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.Message;
import android.util.Log;

import androidx.annotation.NonNull;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;

import io.wazo.callkeep.BuildConfig;

public class UdpLog {

    private static final String HOST = BuildConfig.UDP_LOG_HOST;
    private static final int PORT = BuildConfig.UDP_LOG_PORT;
    private static boolean isEnabled() { return (PORT > 0); }

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

        @Override
        public void handleMessage(Message msg) {
            try
            {
                String message = (String) msg.obj;
                byte[] sendBuffer = message.getBytes();
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

    public static void sendln(@NonNull String tag, @NonNull String logMessage) {
        if (!isEnabled()) {
            Log.d(TAG, "Logger isn't enabled, skip message: " + logMessage);
            return;
        }

        if (_instance == null) {
            _instance = new UdpLog();
        }

        Message msg = _instance._handler.obtainMessage();
        msg.obj = tag + ": " + logMessage + '\n';
        _instance._handler.sendMessage(msg);
    }
}
