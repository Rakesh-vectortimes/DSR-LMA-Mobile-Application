/// Named route paths for go_router.
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const lma = '/home/lma';
  static const dsr = '/home/dsr';
  static const more = '/home/more';

  static const lmaCreate = '/lma/create';
  static String lmaEdit(String id) => '/lma/edit/$id';
  static String lmaPreview(String id) => '/lma/$id';
  static const lmaSettings = '/lma-settings';

  static const dsrCreate = '/dsr/create';
  static String dsrEdit(String id) => '/dsr/edit/$id';
  static String dsrPreview(String id) => '/dsr/$id';
}
