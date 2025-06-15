Clear-Host
Write-Host "Generador de proyectos Spring Boot"

function UrlEncode($str) {
    [System.Net.WebUtility]::UrlEncode($str)
}

# Solicitar datos
$projectName = Read-Host "Nombre del proyecto"
$basePackage = Read-Host "Nombre del paquete base (ej. com.ticketflex.app)"
$database = Read-Host "¿Que base de datos deseas usar? (h2, mysql, postgresql, ninguna)"
$description = Read-Host "Descripcion del proyecto"

if ([string]::IsNullOrWhiteSpace($projectName) -or [string]::IsNullOrWhiteSpace($basePackage)) {
    Write-Error "El nombre del proyecto y el paquete base son obligatorios."
    exit
}

$validDatabases = @("h2", "mysql", "postgresql", "ninguna")
if (-not $validDatabases.Contains($database)) {
    Write-Error "Base de datos no válida. Usa solo: h2, mysql, postgresql o ninguna."
    exit
}

# Preparar parámetros
$groupId = $basePackage
$zipFile = "$projectName.zip"
$encodedProjectName = UrlEncode $projectName
$encodedBasePackage = UrlEncode $basePackage
$encodedDescription = UrlEncode $description

$dependencies = if ($database -eq "ninguna") {
    "web,thymeleaf,devtools"
} else {
    "web,thymeleaf,data-jpa,$database,devtools"
}

$url = "https://start.spring.io/starter.zip?type=maven-project&language=java&baseDir=$encodedProjectName&groupId=$encodedBasePackage&artifactId=$encodedProjectName&name=$encodedProjectName&description=$encodedDescription&packageName=$encodedBasePackage&dependencies=$dependencies"

# Descargar y extraer proyecto
Write-Host "Descargando proyecto desde Spring Initializr..."
Invoke-WebRequest -Uri $url -OutFile $zipFile -ErrorAction Stop
Expand-Archive -Path $zipFile -DestinationPath . -Force
Remove-Item $zipFile

$projectDir = ".\$projectName"
$basePath = Join-Path "$projectDir\src\main\java" ($basePackage -replace '\.', '\\')

# Crear carpetas
Write-Host "Creando carpetas MVC..."
New-Item "$basePath\controller" -ItemType Directory -Force | Out-Null
New-Item "$basePath\service" -ItemType Directory -Force | Out-Null
New-Item "$basePath\model" -ItemType Directory -Force | Out-Null
New-Item "$basePath\repository" -ItemType Directory -Force | Out-Null
New-Item "$projectDir\src\main\resources\static" -ItemType Directory -Force | Out-Null
New-Item "$projectDir\src\main\resources\templates" -ItemType Directory -Force | Out-Null

# Crear application.properties
Write-Host "Creando archivo application.properties..."
$propFile = "$projectDir\src\main\resources\application.properties"

switch ($database) {
    "h2" {
@"
spring.datasource.url=jdbc:h2:mem:testdb
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=sa
spring.datasource.password=
spring.jpa.database-platform=org.hibernate.dialect.H2Dialect
spring.h2.console.enabled=true
"@ | Set-Content -Encoding UTF8 $propFile
    }
    "mysql" {
@"
spring.datasource.url=jdbc:mysql://localhost:3306/testdb
spring.datasource.username=root
spring.datasource.password=1234
spring.jpa.hibernate.ddl-auto=update
spring.jpa.database-platform=org.hibernate.dialect.MySQLDialect
"@ | Set-Content -Encoding UTF8 $propFile
    }
    "postgresql" {
@"
spring.datasource.url=jdbc:postgresql://localhost:5432/testdb
spring.datasource.username=postgres
spring.datasource.password=1234
spring.jpa.hibernate.ddl-auto=update
spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect
"@ | Set-Content -Encoding UTF8 $propFile
    }
    "ninguna" {
@"
spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration
"@ | Set-Content -Encoding UTF8 $propFile
    }
}

# Generar clases básicas y HTML
Write-Host "Generando clases base y plantilla HTML..."

# Clase Controller
$controllerClass = @"
package $basePackage.controller;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HomeController {
    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("message", "Bienvenido a $projectName");
        return "index";
    }
}
"@
$controllerClass | Set-Content "$basePath\controller\HomeController.java"

# Clase Service
$serviceClass = @"
package $basePackage.service;

import org.springframework.stereotype.Service;

@Service
public class SampleService {
    public String getGreeting() {
        return "Hola desde el servicio!";
    }
}
"@
$serviceClass | Set-Content "$basePath\service\SampleService.java"

# Clase Model y Repository
if ($database -ne "ninguna") {
    $modelClass = @"
package $basePackage.model;

import jakarta.persistence.*;

@Entity
public class SampleModel {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    private String name;

    public SampleModel() {}

    public SampleModel(String name) {
        this.name = name;
    }

    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public void setName(String name) {
        this.name = name;
    }
}
"@
    $modelClass | Set-Content "$basePath\model\SampleModel.java"

    $repositoryClass = @"
package $basePackage.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import $basePackage.model.SampleModel;

public interface SampleRepository extends JpaRepository<SampleModel, Long> {
}
"@
    $repositoryClass | Set-Content "$basePath\repository\SampleRepository.java"
}
else {
    $modelClass = @"
package $basePackage.model;

public class SampleModel {
    private String name;
    public SampleModel() {}
    public SampleModel(String name) { this.name = name; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
}
"@
    $modelClass | Set-Content "$basePath\model\SampleModel.java"
}

# Clase de firma que protege tu autoría
$firmaClass = @"
package $basePackage.security;

import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;

@Component
public class FirmaAutor {

    private final String autor = "Jhon Fredy Ariza - TicketFlex 2025";

    @PostConstruct
    public void verificarFirma() {
        if (autor == null || !autor.contains("TicketFlex")) {
            throw new RuntimeException("Autenticidad del proyecto comprometida. Contactar al autor original.");
        }
    }

    public String getAutor() {
        return autor;
    }
}
"@
New-Item "$basePath\security" -ItemType Directory -Force | Out-Null
$firmaClass | Set-Content "$basePath\security\FirmaAutor.java"


# HTML con Thymeleaf
# Modificar HTML para incluir marca visual
$html = @"
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head>
    <meta charset="UTF-8">
    <title>$projectName</title>
</head>
<body>
    <h1 th:text="`${message}`">Default message</h1>
    <footer style="position:fixed;bottom:10px;right:10px;opacity:0.2;font-size:small;">
        Desarrollado por Jhon Fredy Ariza - TicketFlex 2025
    </footer>
</body>
</html>
"@
$html | Set-Content "$projectDir\src\main\resources\templates\index.html"

# Compilar proyecto si Maven está disponible
Write-Host "Compilando el proyecto..."
if (Get-Command mvn -ErrorAction SilentlyContinue) {
    Push-Location $projectDir
    mvn clean install
    Pop-Location
} else {
    Write-Warning "mvn no esta instalado. Compilacion omitida."
}

Write-Host "Proyecto '$projectName' creado correctamente con estructura basica."

