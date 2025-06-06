# Copilot Instructions

Please follow these guidelines when suggesting or generating code to ensure consistency with our architecture and best practices.

## Before You Start Each And Every Task
- Start by making a plan before writing any code, and ensure the plan is approved before proceeding (do not create a new file for this plan).

## What The Structure Of Our Codebase Looks Like
- This is a monorepo containing both front-end and back-end code.
- The front-end is built with Vue.js and TypeScript, while the back-end is built with PHP and Laravel.
- Vue components are located in `x`.
- Vuex store modules are located in `x`.
- PHP code is organized using Domain-Driven Design (DDD) principles, with each domain having its own directory under `app/DDD`.

## 🧱 Front-End (JavaScript/TypeScript)

### ✅ Use:
- Functional components where possible.
- Component reuse and encapsulation.
- TailwindCSS styled components.

### 📦 Structure:
- Each component should be isolated in its own file.
- Each component should reference TailwindCSS classes for styling.
- Each component should be responsible for its own state management.
- Use hooks for state management and side effects (e.g., `useState`, `useEffect`).
- Reference and use vuex for state management where applicable (these are located in `x`).

## 🧠 Back-End (PHP/Laravel)

### 🏗️ Layered Architecture:
Use the **Controller → Service → Repository** pattern:
- **Validators**: Use validators to validate input data before processing.
- **Repositories**: Use repositories to abstract data access logic and provide a clean interface for data operations.
- **Services**: Use services to encapsulate business logic and provide a clean interface for controllers.
- **Controllers**: Use controllers to handle HTTP requests and responses, delegating business logic to services.
- **DTOs**: Use Data Transfer Objects to validate and transfer data between layers.
- **Entities**: Use entities to represent your data models.
- **Factories**: Use factories to create complex objects or entities.
- **Events**: Use events to decouple components and handle asynchronous operations.
- **Listeners**: Use listeners to respond to events and perform actions.
- **Jobs**: Use jobs for background processing and long-running tasks.

### 📐 Guidelines:
- Keep each layer thin and focused on its role.
- Ensure code is clean, modular, well-typed, and easy to maintain, with a focus on performance and scalability.
- Do not use docblocks, instead use type hints for method parameters and return types.
- Never access the repository directly from outside the service layer (unless there is a valid reason).
- Follow code best practices for both front-end and back-end (PSR standards and adhere to linting rules).
- Always validate input and handle errors gracefully.
- Avoid putting business logic in controllers or repositories.
- Avoid side effects in components.
- Avoid putting comments in the code; instead, use meaningful variable and function names to make the code self-documenting.
- Remove unused imports and variables.

## 🔍 Testing & Documentation

- Use PHPUnit for back-end tests and Jest for front-end tests.
- Tests for PHPUnit outside DDD projects should be placed in the `tests` directory (e.g., `tests/Unit/Services/UserServiceTest.php`)
- Tests for PHPUnit within DDD projects should be placed within the project directory (e.g., `app/DDD/Domain/User/Tests/UserServiceTest.php`).
- Ensure tests cover all edge cases and are easy to understand.
- Use descriptive names for tests to clearly indicate what they are testing.
- Write tests that are easy to read and understand, focusing on the behavior of the code rather than implementation details.
- Use descriptive names for test files and directories to reflect the functionality being tested (e.g., `UserServiceTest.php` for testing the `UserService` class).

## 📚 Naming Conventions

- Use descriptive, consistent naming for all variables, classes, functions, and files.
- File names should match the exported class/function (e.g., `UserService.ts` should export `UserService`).

## ✅ Code Quality

- Ensure no linting or type errors.
- We use eslint for JavaScript/TypeScript and phpcs for PHP.
- Prefer readability and maintainability over overly abstract or complex solutions.
- Write DRY (Don't Repeat Yourself), KISS (Keep It Simple, Stupid), and SOLID code.

## Running Commands

- This local setup uses Docker, so you should run commands inside the Docker container.
- For PHP commands, use `docker exec {container_name} php <command>`.
- For Node commands, use `docker exec {container_name} <command>`.
- We always use the {container_name} container for running commands, as it has all the necessary dependencies installed.

---
