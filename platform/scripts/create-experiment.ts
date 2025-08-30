#!/usr/bin/env node

import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { promises as fs } from 'fs';
import { existsSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

interface ExperimentMetadata {
  id: string;
  name: string;
  description: string;
  version: string;
  author: string;
  tags: string[];
  createdAt: string;
  updatedAt: string;
  dependencies: Record<string, string>;
  scripts: Record<string, string>;
  status: 'draft' | 'active' | 'completed' | 'archived';
}

class ExperimentScaffolder {
  private projectRoot: string;
  private experimentsDir: string;
  private templatesDir: string;
  private registryFile: string;

  constructor() {
    this.projectRoot = join(__dirname, '../..');
    this.experimentsDir = join(this.projectRoot, 'experiments');
    this.templatesDir = join(this.projectRoot, 'platform/templates');
    this.registryFile = join(this.projectRoot, 'registry/index.ndjson');
  }

  private kebabCase(str: string): string {
    return str
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-');
  }

  private pascalCase(str: string): string {
    return str
      .split(/[-_\s]+/)
      .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join('');
  }

  private async ensureDirectories(): Promise<void> {
    const dirs = [
      this.experimentsDir,
      join(this.projectRoot, 'registry'),
      this.templatesDir
    ];

    for (const dir of dirs) {
      if (!existsSync(dir)) {
        await fs.mkdir(dir, { recursive: true });
      }
    }
  }

  private async copyTemplate(templateName: string, targetDir: string, replacements: Record<string, string>): Promise<void> {
    const templatePath = join(this.templatesDir, templateName);
    
    if (!existsSync(templatePath)) {
      console.warn(`Template ${templateName} not found, creating basic structure`);
      return;
    }

    const files = await fs.readdir(templatePath, { recursive: true });
    
    for (const file of files) {
      const sourcePath = join(templatePath, file as string);
      const stat = await fs.stat(sourcePath);
      
      if (stat.isFile()) {
        let content = await fs.readFile(sourcePath, 'utf-8');
        
        // Replace template variables
        for (const [key, value] of Object.entries(replacements)) {
          const regex = new RegExp(`{{${key}}}`, 'g');
          content = content.replace(regex, value);
        }
        
        const targetPath = join(targetDir, file as string);
        await fs.mkdir(dirname(targetPath), { recursive: true });
        await fs.writeFile(targetPath, content);
      }
    }
  }

  private async createBasicStructure(experimentDir: string, experimentName: string): Promise<void> {
    const structure = [
      'src',
      'tests',
      'docs',
      'config',
      'data',
      'scripts',
      'outputs'
    ];

    for (const dir of structure) {
      await fs.mkdir(join(experimentDir, dir), { recursive: true });
    }

    // Create basic files
    const packageJson = {
      name: experimentName,
      version: "0.1.0",
      description: `Experiment: ${experimentName}`,
      main: "src/index.ts",
      scripts: {
        start: "tsx src/index.ts",
        build: "tsc",
        test: "jest",
        dev: "tsx watch src/index.ts"
      },
      dependencies: {
        "typescript": "^5.0.0",
        "tsx": "^4.0.0"
      },
      devDependencies: {
        "@types/node": "^20.0.0",
        "jest": "^29.0.0",
        "@types/jest": "^29.0.0"
      }
    };

    await fs.writeFile(
      join(experimentDir, 'package.json'),
      JSON.stringify(packageJson, null, 2)
    );

    // Create tsconfig.json
    const tsConfig = {
      compilerOptions: {
        target: "ES2022",
        module: "ESNext",
        moduleResolution: "node",
        strict: true,
        esModuleInterop: true,
        skipLibCheck: true,
        forceConsistentCasingInFileNames: true,
        outDir: "./dist",
        rootDir: "./src",
        resolveJsonModule: true,
        declaration: true,
        declarationMap: true,
        sourceMap: true
      },
      include: ["src/**/*"],
      exclude: ["node_modules", "dist", "tests"]
    };

    await fs.writeFile(
      join(experimentDir, 'tsconfig.json'),
      JSON.stringify(tsConfig, null, 2)
    );

    // Create basic source file
    const indexContent = `/**
 * ${this.pascalCase(experimentName)} Experiment
 * Generated on ${new Date().toISOString()}
 */

export class ${this.pascalCase(experimentName)}Experiment {
  private config: any;

  constructor(config: any = {}) {
    this.config = config;
    console.log(\`Starting \${${this.pascalCase(experimentName)}Experiment.name} experiment\`);
  }

  async run(): Promise<void> {
    console.log('Experiment execution started');
    
    // TODO: Implement your experiment logic here
    
    console.log('Experiment execution completed');
  }

  async setup(): Promise<void> {
    console.log('Setting up experiment environment');
    // TODO: Add setup logic
  }

  async cleanup(): Promise<void> {
    console.log('Cleaning up experiment resources');
    // TODO: Add cleanup logic
  }

  getResults(): any {
    // TODO: Return experiment results
    return {};
  }
}

// CLI execution
if (import.meta.url === \`file://\${process.argv[1]}\`) {
  const experiment = new ${this.pascalCase(experimentName)}Experiment();
  
  experiment.setup()
    .then(() => experiment.run())
    .then(() => experiment.cleanup())
    .then(() => {
      const results = experiment.getResults();
      console.log('Results:', results);
    })
    .catch(console.error);
}
`;

    await fs.writeFile(join(experimentDir, 'src/index.ts'), indexContent);

    // Create README
    const readmeContent = `# ${this.pascalCase(experimentName)} Experiment

## Description

TODO: Add experiment description

## Setup

\`\`\`bash
npm install
\`\`\`

## Usage

\`\`\`bash
npm start
\`\`\`

## Development

\`\`\`bash
npm run dev
\`\`\`

## Testing

\`\`\`bash
npm test
\`\`\`

## Configuration

TODO: Document configuration options

## Results

TODO: Document expected results and outputs
`;

    await fs.writeFile(join(experimentDir, 'README.md'), readmeContent);

    // Create basic test
    const testContent = `import { ${this.pascalCase(experimentName)}Experiment } from '../src/index';

describe('${this.pascalCase(experimentName)}Experiment', () => {
  let experiment: ${this.pascalCase(experimentName)}Experiment;

  beforeEach(() => {
    experiment = new ${this.pascalCase(experimentName)}Experiment();
  });

  it('should initialize properly', () => {
    expect(experiment).toBeInstanceOf(${this.pascalCase(experimentName)}Experiment);
  });

  it('should run without errors', async () => {
    await expect(experiment.run()).resolves.not.toThrow();
  });

  it('should return results', () => {
    const results = experiment.getResults();
    expect(results).toBeDefined();
  });
});
`;

    await fs.writeFile(join(experimentDir, 'tests/index.test.ts'), testContent);

    // Create jest config
    const jestConfig = {
      preset: 'ts-jest',
      testEnvironment: 'node',
      roots: ['<rootDir>/tests'],
      testMatch: ['**/*.test.ts'],
      collectCoverageFrom: ['src/**/*.ts'],
      coverageDirectory: 'coverage',
      coverageReporters: ['text', 'lcov', 'html']
    };

    await fs.writeFile(
      join(experimentDir, 'jest.config.json'),
      JSON.stringify(jestConfig, null, 2)
    );

    // Create .gitignore
    const gitignoreContent = `node_modules/
dist/
coverage/
*.log
.env
.DS_Store
outputs/
data/raw/
`;

    await fs.writeFile(join(experimentDir, '.gitignore'), gitignoreContent);
  }

  private async updateRegistry(metadata: ExperimentMetadata): Promise<void> {
    const registryEntry = JSON.stringify(metadata);
    
    try {
      await fs.appendFile(this.registryFile, registryEntry + '\n');
    } catch (error) {
      // Create file if it doesn't exist
      await fs.writeFile(this.registryFile, registryEntry + '\n');
    }
  }

  async createExperiment(experimentName: string): Promise<void> {
    console.log(`Creating experiment: ${experimentName}`);

    await this.ensureDirectories();

    const kebabName = this.kebabCase(experimentName);
    const experimentDir = join(this.experimentsDir, kebabName);

    // Check if experiment already exists
    if (existsSync(experimentDir)) {
      throw new Error(`Experiment '${kebabName}' already exists`);
    }

    // Create experiment directory
    await fs.mkdir(experimentDir, { recursive: true });

    // Create replacements for templates
    const replacements = {
      EXPERIMENT_NAME: kebabName,
      EXPERIMENT_CLASS: this.pascalCase(experimentName),
      EXPERIMENT_TITLE: experimentName,
      CREATED_DATE: new Date().toISOString(),
      AUTHOR: process.env.USER || 'unknown'
    };

    // Copy template or create basic structure
    try {
      await this.copyTemplate('base', experimentDir, replacements);
    } catch (error) {
      console.warn('Template not found, creating basic structure');
      await this.createBasicStructure(experimentDir, kebabName);
    }

    // Create metadata
    const metadata: ExperimentMetadata = {
      id: kebabName,
      name: experimentName,
      description: `Experiment: ${experimentName}`,
      version: '0.1.0',
      author: process.env.USER || 'unknown',
      tags: ['experiment', 'new'],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      dependencies: {
        typescript: '^5.0.0',
        tsx: '^4.0.0'
      },
      scripts: {
        start: 'tsx src/index.ts',
        build: 'tsc',
        test: 'jest',
        dev: 'tsx watch src/index.ts'
      },
      status: 'draft'
    };

    // Update registry
    await this.updateRegistry(metadata);

    console.log(`✅ Experiment '${kebabName}' created successfully!`);
    console.log(`📁 Location: ${experimentDir}`);
    console.log(`🚀 Get started: cd experiments/${kebabName} && npm install && npm start`);
  }
}

// CLI interface
async function main() {
  const experimentName = process.argv[2];

  if (!experimentName) {
    console.error('Usage: node create-experiment.js <experiment-name>');
    console.error('Example: node create-experiment.js "My New Experiment"');
    process.exit(1);
  }

  try {
    const scaffolder = new ExperimentScaffolder();
    await scaffolder.createExperiment(experimentName);
  } catch (error) {
    console.error('Error creating experiment:', error);
    process.exit(1);
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export { ExperimentScaffolder };