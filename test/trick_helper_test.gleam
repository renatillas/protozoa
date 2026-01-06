import protozoa/internal/codegen/trick_router
import trick

fn test_helper(helper: trick.Definition) {
  let assert Ok(_) = trick.to_string(helper)
}

pub fn helper_query_string_test() {
  test_helper(trick_router.generate_query_string_helper())
}

pub fn helper_query_int_test() {
  test_helper(trick_router.generate_query_int_helper())
}

pub fn helper_query_bool_test() {
  test_helper(trick_router.generate_query_bool_helper())
}

pub fn helper_query_float_test() {
  test_helper(trick_router.generate_query_float_helper())
}

pub fn helper_query_list_string_test() {
  test_helper(trick_router.generate_query_list_string_helper())
}

pub fn helper_query_list_int_test() {
  test_helper(trick_router.generate_query_list_int_helper())
}

pub fn helper_query_optional_string_test() {
  test_helper(trick_router.generate_query_optional_string_helper())
}

pub fn helper_query_optional_int_test() {
  test_helper(trick_router.generate_query_optional_int_helper())
}

// Note: Path parameters are now passed as function arguments to HTTP adapters,
// so path extraction helpers are no longer needed.
