namespace :api_docs do
  desc "Run API contract specs and build OpenAPI JSON plus a portable Scalar site"
  task :build do
    require "json"
    require "json_schemer"
    require "fileutils"
    require "cgi"

    assets = Rails.root.join("node_modules/@scalar/api-reference")
    unless assets.join("dist/browser/standalone.js").file?
      abort "Scalar assets are missing. Run npm ci in app/ before building the API reference."
    end

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

    %w[swagger-ui.css swagger-ui-bundle.js LICENSE NOTICE].each do |file|
      FileUtils.rm_f(output.join(file))
    end
    FileUtils.cp(assets.join("dist/browser/standalone.js"), output.join("scalar.js"))
    FileUtils.cp(Rails.root.join("../docs/api/licenses/scalar.txt"), output.join("scalar-LICENSE"))

    # Embed the spec so index.html also works directly from disk, without fetch,
    # a running Rails app, a CDN, or a separate static web server.
    embedded_json = json.gsub("<", '\\u003c').gsub(">", '\\u003e').gsub("&", '\\u0026')
    output.join("index.html").write(<<~HTML)
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>#{CGI.escapeHTML(document.fetch("info").fetch("title"))}</title>
          <style>
            body { margin: 0; }
          </style>
        </head>
        <body>
          <div id="emmy-api-reference"></div>
          <script src="scalar.js"></script>
          <script>
            Scalar.createApiReference("#emmy-api-reference", {
              content: #{embedded_json},
              layout: "modern",
              theme: "default",
              darkMode: false,
              withDefaultFonts: false,
              hideTestRequestButton: true,
              hideClientButton: true,
              showDeveloperTools: "never",
              agent: { disabled: true },
              telemetry: false
            });
          </script>
        </body>
      </html>
    HTML
    puts "API reference: #{output.join('index.html')}"
  end
end
