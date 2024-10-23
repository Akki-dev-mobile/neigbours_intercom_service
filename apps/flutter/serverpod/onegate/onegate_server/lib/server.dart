import 'package:serverpod/serverpod.dart';
import 'package:onegate_server/src/web/routes/root.dart';
import 'src/generated/protocol.dart';
import 'src/generated/endpoints.dart';
import 'package:serverpod_cloud_storage_s3/serverpod_cloud_storage_s3.dart' as s3;

void run(List<String> args) async {
  // Initialize Serverpod and connect it with your generated code.
  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
  );

  // If you are using any future calls, they need to be registered here.
  // pod.registerFutureCall(ExampleFutureCall(), 'exampleFutureCall');

  // Setup a default page at the web root.
  pod.webServer.addRoute(RouteRoot(), '/');
  pod.webServer.addRoute(RouteRoot(), '/index.html');

  // Serve all files in the /static directory.
  pod.webServer.addRoute(
    RouteStaticDirectory(serverDirectory: 'static', basePath: '/'),
    '/*',
  );

  // Adding S3 Cloud Storage with proper error handling.
  try {
    pod.addCloudStorage(s3.S3CloudStorage(
      serverpod: pod,
      storageId: 'public',
      public: true,
      region: 'ap-south-1',
      bucket: 'fstech-serverpod',
      // publicHost: 'storage.myapp.com',
    ));
    print('S3 Cloud Storage configured successfully.');
  } catch (e) {
    print('Failed to configure S3 Cloud Storage: $e');
  }

  // Start the server.
  await pod.start();
}