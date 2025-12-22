class AlgoliaConfig {
  static const String applicationId = 'LCRXB468SS';
  static const String adminApiKey = '150ee3747f284050a0b890d73e49ef83'; // Keep secure!
  static const String searchApiKey = '2d3743b68a33a961e2b8e4f195130ffa'; // Safe for client
  static const String indexName = 'posts';

  // Add this method for testing
  static void printConfig() {
    print('📋 ALGOLIA CONFIG:');
    print('   App ID: $applicationId');
    print('   Search Key: ${searchApiKey.substring(0, 10)}...');
    print('   Admin Key: ${adminApiKey.substring(0, 10)}...');
    print('   Index: $indexName');
  }
}
