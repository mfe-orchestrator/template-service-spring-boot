package dev.mfeorchestrator.service;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
@Tag(name = "hello")
public class HelloController {

    public record HelloResponse(String message) {
    }

    @Operation(summary = "Example endpoint")
    @GetMapping("/hello")
    public HelloResponse hello() {
        return new HelloResponse("Hello from %serviceSlug%");
    }
}
