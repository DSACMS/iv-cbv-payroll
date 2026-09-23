namespace :api_docs do
  desc "Run API contract specs and build OpenAPI JSON plus a portable Swagger UI site"
  task :build do
    require "json"
    require "json_schemer"
    require "fileutils"

    # Always execute the specs, even if rswag's dry-run option is set elsewhere.
    # Generate in tmp so a failed test cannot overwrite the published contract.
    sh({ "RAILS_ENV" => "test", "RSWAG_DRY_RUN" => "0" },
      "bundle", "exec", "rspec", "--options", "/dev/null",
      "--order", "defined", "--format", "Rswag::Specs::SwaggerFormatter",
      "--format", "progress", "spec/requests/api")

    output = Rails.root.join("tmp/api-docs")
    document = JSON.parse(output.join("openapi.json").read)
    validator = JSONSchemer.openapi(document)
    errors = validator.validate.to_a
    abort "Invalid OpenAPI document: #{errors.inspect}" if errors.any?

    # Validate every published example, including all variants of each response.
    document.fetch("paths").each do |path, operations|
      operations.each do |method, operation|
        body_paths = [ [ "requestBody" ], *operation.fetch("responses").keys.map { |status| [ "responses", status ] } ]
        body_paths.each do |body_path|
          body = operation.dig(*body_path)
          next unless body

          body.fetch("content", {}).each do |mime, media|
            pointer = [ "paths", path, method, *body_path, "content", mime, "schema" ]
              .map { |part| part.gsub("~", "~0").gsub("/", "~1") }.join("/")
            schema = validator.ref("#/#{pointer}")
            media.fetch("examples", {}).each do |name, example|
              errors = schema.validate(example.fetch("value")).to_a
              abort "Invalid #{method.upcase} #{path} example #{name}: #{errors.inspect}" if errors.any?
            end
          end
        end
      end
    end

    # rswag omits the final newline; keep the checked-in artifact lint-clean.
    json = JSON.pretty_generate(document) + "\n"
    output.join("openapi.json").write(json)
    FileUtils.cp(output.join("openapi.json"), Rails.root.join("../docs/api/openapi.json"))

    assets = Gem::Specification.find_by_name("rswag-ui").full_gem_path
    %w[swagger-ui.css swagger-ui-bundle.js LICENSE NOTICE].each do |file|
      FileUtils.cp(File.join(assets, "node_modules/swagger-ui-dist", file), output.join(file))
    end

    # Embed the spec so index.html also works directly from disk, without fetch,
    # a running Rails app, a CDN, or a separate static web server.
    embedded_json = json.gsub("<", '\\u003c').gsub(">", '\\u003e').gsub("&", '\\u0026')
    output.join("index.html").write(<<~HTML)
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Emmy Tokenized Link API</title>
          <link rel="stylesheet" href="swagger-ui.css">
        </head>
        <body>
          <div id="swagger-ui"></div>
          <script src="swagger-ui-bundle.js"></script>
          <script>
            SwaggerUIBundle({
              spec: #{embedded_json},
              dom_id: "#swagger-ui",
              deepLinking: true,
              validatorUrl: null,
              supportedSubmitMethods: [],
              defaultModelsExpandDepth: 1
            });
          </script>
        </body>
      </html>
    HTML
    puts "API reference: #{output.join('index.html')}"
  end
end
