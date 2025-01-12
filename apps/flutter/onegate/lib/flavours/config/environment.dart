abstract class Environment {
  static late String baseUrl;

  static void init(String env) {
    switch (env) {
      case 'dev':
        baseUrl = 'https://dev.example.com';
        break;
      case 'staging':
        baseUrl = 'https://staging.example.com';
        break;
      case 'prod':
        baseUrl = 'https://prod.example.com';
        break;
      default:
        throw Exception('Invalid environment');
    }
  }
}