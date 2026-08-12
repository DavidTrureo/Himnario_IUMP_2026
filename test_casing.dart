import 'lib/features/hymns/domain/hymn.dart';

void main() {
  print("Line 1: " + Hymn.formatLineCasing("1. A Abraham y a Sara un hijo Dios plugo prometer"));
  print("Line 2: " + Hymn.formatLineCasing("Hizo Moisés, serpiente, y en asta levantó"));
  print("Line 3: " + Hymn.formatLineCasing("Cuando Josué dio orden, el sol por él paró"));
}
