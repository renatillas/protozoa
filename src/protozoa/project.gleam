import filepath
import gleam/result
import simplifile
import tom

pub fn root() -> String {
  find_root(".")
}

pub fn src() -> String {
  filepath.join(root(), "src")
}

pub fn name() -> Result(String, Nil) {
  let configuration_path = filepath.join(root(), "gleam.toml")

  use configuration <- result.try(
    simplifile.read(configuration_path)
    |> result.map_error(fn(_) { Nil }),
  )
  use toml <- result.try(
    tom.parse(configuration)
    |> result.map_error(fn(_) { Nil }),
  )
  use name <- result.try(
    tom.get_string(toml, ["name"])
    |> result.map_error(fn(_) { Nil }),
  )
  Ok(name)
}

fn find_root(path: String) -> String {
  let toml = filepath.join(path, "gleam.toml")

  case simplifile.is_file(toml) {
    Ok(False) | Error(_) -> find_root(filepath.join(path, ".."))
    Ok(True) -> path
  }
}
