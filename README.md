asset_generator

A Flutter/Dart code generator that automatically creates strongly-typed asset access classes based on the folders you specify.
No more manually typing long asset paths or worrying about typos — this generator produces a clean, organized API for your project’s assets.

✨ Features

🔍 Scans asset folders listed in your pubspec.yaml

🛠 Generates a strongly-typed asset context class

📁 Supports single or multiple folders

📦 Outputs .g.dart files using source_gen & build_runner

🎯 Eliminates string-based asset paths

💡 IDE auto-completion for all assets

📦 Installation

Add the annotation and generator to your pubspec.yaml:

dependencies:
asset_generator:
git: https://github.com/YannVanneth/asset_generator

dev_dependencies:
build_runner: ^2.4.9


Replace the Git URL with your actual repository.

🧩 Usage
1. Add assets to your pubspec.yaml:
   flutter:
   assets:
    - assets/icons/
    - assets/images/

2. Annotate an abstract class
   import 'package:asset_generator/asset_generator.dart';

@GenerateAssets(folder: "assets/icons")
abstract class Icons {}


This will generate a file named:

icons.g.dart


With a context class:

class _IconsContext {
// Generated asset getters...
}

3. Extend the generated context
   class Icons extends _IconsContext {}


Now you can use your assets like this:

Image.asset(Icons.home);


With full auto-complete support!

⚙️ Annotation Parameters
const GenerateAssets({
this.folder = '',
this.folders = const [],
this.className = '',
});

Parameter	Type	Description
folder	String	Directory to scan for assets (single folder).
folders	List<String>	Scan multiple folders.
className	String	Optional: override the generated context class name.
📝 Example With Multiple Folders
@GenerateAssets(
folders: [
"assets/icons",
"assets/images",
],
)
abstract class AppAssets {}

class AppAssets extends _AppAssetsContext {}

🔧 Running the Generator

In your terminal:

dart run build_runner build


Or watch mode:

dart run build_runner watch

📁 Output Structure Example

For this folder:

assets/icons/home.png
assets/icons/user.png


The generated class will contain:

static const String home = 'assets/icons/home.png';
static const String user = 'assets/icons/user.png';

🤝 Contributing

Contributions are welcome!
Feel free to open issues or pull requests on the GitHub repo.

📄 License

MIT License. Use freely in personal and commercial projects.