#!/bin/bash

echo "Generador de proyectos Spring Boot"

read -p "Nombre del proyecto: " projectName
read -p "Nombre del paquete base (ej. com.ticketflex.app): " basePackage
read -p "¿Qué base de datos deseas usar? (h2, mysql, postgresql, ninguna): " database
read -p "Descripción del proyecto: " description

if [[ -z "$projectName" || -z "$basePackage" ]]; then
    echo "El nombre del proyecto y el paquete base son obligatorios."
    exit 1
fi

validDatabases=("h2" "mysql" "postgresql" "ninguna")
if [[ ! " ${validDatabases[@]} " =~ " ${database} " ]]; then
    echo "Base de datos no válida. Usa solo: h2, mysql, postgresql o ninguna."
    exit 1
fi

encodedProjectName=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$projectName'''))")
encodedBasePackage=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$basePackage'''))")
encodedDescription=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$description'''))")

if [[ "$database" == "ninguna" ]]; then
    dependencies="web,thymeleaf,devtools"
else
    dependencies="web,thymeleaf,data-jpa,${database},devtools"
fi

url="https://start.spring.io/starter.zip?type=maven-project&language=java&baseDir=$encodedProjectName&groupId=$encodedBasePackage&artifactId=$encodedProjectName&name=$encodedProjectName&description=$encodedDescription&packageName=$encodedBasePackage&dependencies=$dependencies"

echo "Descargando proyecto desde Spring Initializr..."
curl -s -o "$projectName.zip" "$url"
unzip -q "$projectName.zip"
rm "$projectName.zip"

projectDir="./$projectName"
basePath="$projectDir/src/main/java/$(echo "$basePackage" | tr '.' '/')"

echo "Creando carpetas MVC..."
mkdir -p "$basePath/controller" "$basePath/service" "$basePath/model" "$basePath/repository"
mkdir -p "$projectDir/src/main/resources/static"
mkdir -p "$projectDir/src/main/resources/templates"
mkdir -p "$basePath/security"

echo "Creando archivo application.properties..."
propFile="$projectDir/src/main/resources/application.properties"

case "$database" in
    h2)
        cat > "$propFile" <<EOF
spring.datasource.url=jdbc:h2:mem:testdb
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=sa
spring.datasource.password=
spring.jpa.database-platform=org.hibernate.dialect.H2Dialect
spring.h2.console.enabled=true
EOF
        ;;
    mysql)
        cat > "$propFile" <<EOF
spring.datasource.url=jdbc:mysql://localhost:3306/testdb
spring.datasource.username=root
spring.datasource.password=1234
spring.jpa.hibernate.ddl-auto=update
spring.jpa.database-platform=org.hibernate.dialect.MySQLDialect
EOF
        ;;
    postgresql)
        cat > "$propFile" <<EOF
spring.datasource.url=jdbc:postgresql://localhost:5432/testdb
spring.datasource.username=postgres
spring.datasource.password=1234
spring.jpa.hibernate.ddl-auto=update
spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect
EOF
        ;;
    ninguna)
        echo "spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration" > "$propFile"
        ;;
esac

echo "Generando clases base..."

# Controller
cat > "$basePath/controller/HomeController.java" <<EOF
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
EOF

# Service
cat > "$basePath/service/SampleService.java" <<EOF
package $basePackage.service;

import org.springframework.stereotype.Service;

@Service
public class SampleService {
    public String getGreeting() {
        return "Hola desde el servicio!";
    }
}
EOF

# Model y Repository
if [[ "$database" != "ninguna" ]]; then
cat > "$basePath/model/SampleModel.java" <<EOF
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
EOF

cat > "$basePath/repository/SampleRepository.java" <<EOF
package $basePackage.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import $basePackage.model.SampleModel;

public interface SampleRepository extends JpaRepository<SampleModel, Long> {
}
EOF

else
cat > "$basePath/model/SampleModel.java" <<EOF
package $basePackage.model;

public class SampleModel {
    private String name;
    public SampleModel() {}
    public SampleModel(String name) { this.name = name; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
}
EOF
fi

# Firma
cat > "$basePath/security/FirmaAutor.java" <<EOF
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
EOF

# HTML básico
cat > "$projectDir/src/main/resources/templates/index.html" <<EOF
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head>
    <meta charset="UTF-8">
    <title>$projectName</title>
</head>
<body>
    <h1 th:text="\${message}">Default message</h1>
    <footer style="position:fixed;bottom:10px;right:10px;opacity:0.2;font-size:small;">
        Desarrollado por Jhon Fredy Ariza - TicketFlex 2025
    </footer>
</body>
</html>
EOF

echo "Compilando el proyecto..."
if command -v mvn &> /dev/null; then
    (cd "$projectDir" && mvn clean install)
else
    echo "mvn no está instalado. Compilación omitida."
fi

echo "✅ Proyecto '$projectName' creado correctamente con estructura básica."

