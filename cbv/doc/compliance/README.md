# Compliance artifacts

In order to maintain and revise compliance materials with minimal fuss, we store all artifacts as text source (eg Markdown, PlantUML, OSCAL), then generate rendered materials for consumption by downstream entities in the assessment and authorization process.

This directory initially just contains system architecture diagrams corresponding to sections 1-12 of a typical System Security Plan (SSP) document.

The source for other things (OSCAL for control descriptions, evidence generation scripts, etc) will appear here over time.

## Documents

### Application Boundary

The UML source of the application boundary is stored at doc/compliance/apps/application.boundary.md.
The rendered output is saved to doc/compliance/rendered/apps/application.boundary.svg

### Logical Data Model

The logical data model will be auto-generated on each database migration.
The rendered output is saved to doc/compliance/rendered/apps/data.logical.pdf

## Development

These plugins may be helpful for editing diagrams.

- vscode: [PlantUML extension](https://marketplace.visualstudio.com/items?itemName=jebbs.plantuml)
  - Use "PlantUML: Export Current File Diagrams" to render the diagram in the current file (eg while iterating)
  - Use "PlantUML: Export Workspace Diagrams" to render all diagrams (eg before pushing a branch)

### VSCode PlantUML Settings

| Setting name | Value |
| ------------ | ----- |
| Diagrams Root | `doc/compliance` |
| Export Format | `svg` |
| Export Out Dir | `doc/compliance/rendered` |
| Export Sub Folder | unchecked |
| File Extensions | append `.md` |
| Render | `PlantUMLServer` |
| Server | `http://localhost:8080` |

### PlantUML Server

The plugin default settings use the public server, https://www.plantuml.com/plantuml, which may **leak sensitive information**. Instead, run a local plantuml server:

```bash
docker run -d -p 8080:8080 plantuml/plantuml-server:jetty
```
