# BTTypes.gd
class_name BTTypes

enum Status { SUCCESS, FAILURE, RUNNING }

enum ParallelSuccessPolicy { REQUIRE_ALL, REQUIRE_ANY }
enum ParallelFailurePolicy { REQUIRE_ALL, REQUIRE_ANY }
