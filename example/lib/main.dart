import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opengl_texture/opengl_texture.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _controller = new OpenGLTextureController();
  final _width = 1280.0;
  final _height = 720.0;

  Texture? _texture;

  @override
  initState() {
    super.initState();

    initializeController();
    _startPlay();
  }

  void _startPlay() {
    Future.delayed(const Duration(seconds: 5), () {
      print('load data');
       _controller.loadData();
    });
    Future.delayed(const Duration(seconds: 10), () {
      _texture =  _controller.isInitialized
          ? new Texture(textureId: _controller.textureId)
          : null;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text('OpenGL via Texture widget example'),
        ),
        body: new Center(
          child: new Container(
            // width: _width,
            // height: _height,
            child: AspectRatio(aspectRatio: 16/9, child: _texture),
          ),
        ),
      ),
    );
  }

  Future<Null> initializeController() async {
    await _controller.initialize(_width, _height);
    print('initializeController');
    setState(() {});
  }
}
