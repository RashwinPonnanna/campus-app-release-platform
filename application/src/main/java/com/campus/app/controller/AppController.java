package com.campus.app.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
public class AppController {

    @GetMapping("/")
    public String home() {
        return "Campus Application Release Platform - Running";
    }

    // Used by Kubernetes liveness and readiness probes, and by Jenkins smoke tests
    @GetMapping("/health")
    public Map<String, String> health() {
        Map<String, String> status = new HashMap<>();
        status.put("status", "UP");
        return status;
    }

    // Helps verify which build/commit is actually running after a deployment
    @GetMapping("/version")
    public Map<String, String> version() {
        Map<String, String> info = new HashMap<>();
        info.put("version", System.getenv().getOrDefault("APP_VERSION", "dev-local"));
        info.put("commit", System.getenv().getOrDefault("GIT_COMMIT", "unknown"));
        return info;
    }
}
