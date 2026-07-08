import 'package:http/http.dart' as http;

void main() async {
  // Test both endpoints to see if one is 404 and one is 403
  final oldUri = Uri.https('x.com', '/i/api/graphql/Bcw3RzK-PatNAmbnw54hFw/SearchTimeline');
  final newUri = Uri.https('x.com', '/i/api/graphql/R0u1RWRf748KzyGBXvOYRA/SearchTimeline');
  
  final oldRes = await http.get(oldUri);
  print('Old ID Status: ${oldRes.statusCode}');
  
  final newRes = await http.get(newUri);
  print('New ID Status: ${newRes.statusCode}');
}
