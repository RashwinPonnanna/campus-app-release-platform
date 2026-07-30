package com.campus.app;

import com.campus.app.controller.AppController;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class AppControllerTest {

    @Test
    void healthReturnsUp() {
        AppController controller = new AppController();
        assertEquals("UP", controller.health().get("status"));
    }

    @Test
    void homeReturnsExpectedMessage() {
        AppController controller = new AppController();
        assertEquals("Campus Application Release Platform - Running", controller.home());
    }
}
