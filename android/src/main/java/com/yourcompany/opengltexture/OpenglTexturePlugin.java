package com.yourcompany.opengltexture;

import android.graphics.SurfaceTexture;
import android.util.Log;
import android.util.LongSparseArray;

import java.util.Map;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.view.TextureRegistry;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.graphics.YuvImage;
import java.io.ByteArrayOutputStream;

public class YUV420pConverter {

    public static Bitmap convertYUV420pToBitmap(byte[] yuvData, int width, int height) {
        YuvImage yuvImage = new YuvImage(yuvData, ImageFormat.NV21, width, height, null);
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        yuvImage.compressToJpeg(new Rect(0, 0, width, height), 100, outputStream);

        byte[] jpegData = outputStream.toByteArray();
        return BitmapFactory.decodeByteArray(jpegData, 0, jpegData.length);
    }
}


public class OpenglTexturePlugin implements MethodCallHandler {
    private final TextureRegistry textures;
    private LongSparseArray<OpenGLRenderer> renders = new LongSparseArray<>();
    private LongSparseArray<TextureRegistry.SurfaceTextureEntry> entries = new LongSparseArray<>();
    private LongSparseArray<Surface> surfaces = new LongSparseArray<>();
    private Registrar registrar1;

    public OpenglTexturePlugin(TextureRegistry textures) {
        this.textures = textures;
    }

    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "opengl_texture");
        channel.setMethodCallHandler(new OpenglTexturePlugin(registrar.textures()));
        registrar1 = registrar;
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        Map<String, Number> arguments = (Map<String, Number>) call.arguments;
        Log.d("OpenglTexturePlugin", call.method + " " + call.arguments.toString());
        if (call.method.equals("create")) {
            TextureRegistry.SurfaceTextureEntry entry = textures.createSurfaceTexture();
            SurfaceTexture surfaceTexture = entry.surfaceTexture();

            int width = arguments.get("width").intValue();
            int height = arguments.get("height").intValue();
            surfaceTexture.setDefaultBufferSize(width, height);
//
//            SampleRenderWorker worker = new SampleRenderWorker();
//            OpenGLRenderer render = new OpenGLRenderer(surfaceTexture, worker);

//            renders.put(entry.id(), render);
            entries.put(entry.id(), render);

            result.success(entry.id());
        } else if (call.method.equals("dispose")) {
            long textureId = arguments.get("textureId").longValue();
            TextureRegistry.SurfaceTextureEntry entry = entries.get(textureId);
            Surface surface = surfaces[textureId];
            entry.release();
            surface.release();
            entries.delete(textureId);
            surfaces.delete(textureId);
        } else if (call.method.equals("loadData")) {
            long textureId = arguments.get("textureId").longValue();
            val surfaceTextureEntry: TextureRegistry.SurfaceTextureEntry = textureSurfaces[textureId.toLong()]!!
            val surface =
            if (surfaceMap.containsKey(textureId.toLong())) {
                surfaceMap[textureId.toLong()]
            } else {
                val surface = Surface(surfaceTextureEntry.surfaceTexture())
                surfaceMap[textureId.toLong()] = surface
            }
            val canvas: Canvas = surface!!.lockCanvas(null);
            AssetManager assetManager = registrar1.context().getAssets();
            String key = registrar1.lookupKeyForAsset("assets/test.yuv");
            AssetFileDescriptor fd = assetManager.openFd(key);
            System.out.println("Log message");
            byte[] data = null;
            try {
                long length = fd.getLength();
                data = new byte[(int) length];
                fd.createInputStream().read(data);
                fd.close();
            } catch (Exception e) {
                e.printStackTrace();
            }
            int width = 1280; // Width of the image
            int height = 720; // Height of the image
            Bitmap bitmap = YUV420pConverter.convertYUV420pToBitmap(yuvData, width, height);
            canvas.drawBitmap(bitmap, 0F, 0F, null)
            surface.unlockCanvasAndPost(canvas)
        } else {
            result.notImplemented();
        }
    }

    public class AssetFileReader {

        public static byte[] loadBytesFromAsset(Context context, String fileName) {
            byte[] data = null;
            try {
                AssetFileDescriptor assetFileDescriptor = context.getAssets().openFd(fileName);
                long length = assetFileDescriptor.getLength();
                data = new byte[(int) length];
                assetFileDescriptor.createInputStream().read(data);
                assetFileDescriptor.close();
            } catch (Exception e) {
                e.printStackTrace();
            }
            return data;
        }
    }

}

