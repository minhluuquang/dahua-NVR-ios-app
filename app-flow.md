# Screen Design and Application Flow Descriptions

**Date:** July 19, 2025

**Version:** 1.1

---

This document outlines the screen designs and application flow for the NVR Connect iOS application, based on the Product Requirements Document version 1.0 and subsequent updates.

---

### **1. NVR Connection Screen**

* **Purpose:** To allow a user to manually add a new Network Video Recorder (NVR) system by entering its connection credentials.
* **UI Elements:**
    * **Server URL Input Field:** A text field for the user to enter the server address of the NVR.
    * **Username Input Field:** A text field for the NVR username.
    * **Password Input Field:** A secure text field for the NVR password.
    * **Connect Button:** A button that initiates the connection attempt to the NVR using the provided credentials. Upon successful connection, the app will save these details.

---

### **2. NVR List Screen**

* **Purpose:** To manage all saved NVR connections, allowing users to add new systems, switch between existing ones, and set a default connection for the app to use on launch.
* **UI Elements:**
    * **List of Saved NVRs:** A scrollable list displaying the friendly names or server URLs of all previously saved NVR systems.
    * **Default NVR Indicator:** A visual cue (e.g., a star or a "Default" label) next to the NVR system that is currently set as the default.
    * **"Add New NVR" Button:** A prominently placed button that navigates the user to the **NVR Connection Screen**.
    * **Selection Functionality:** Tapping on any NVR in the list will immediately attempt to connect to it.

---

### **3. Main Application Screen**

* **Purpose:** This is the central hub of the application after a successful connection to an NVR. It uses a top toolbar to manage NVR connections and a bottom tab bar for navigation between the main functional areas of the app.
* **UI Elements:**
    * **Toolbar/Navigation Bar:** A bar at the top of the screen. It will display the name of the currently connected NVR as the title.
    * **NVR List Button:** A button located in the toolbar (e.g., an icon of a server list or a "Switch NVR" text button). Tapping this button will navigate the user to the **NVR List Screen**, allowing them to switch to another saved system.
    * **Tab Bar:** A standard iOS tab bar located at the bottom of the screen with five icons and labels:
        * Camera (Default)
        * Storage
        * Network
        * Account
        * System
    * **Content View:** The area between the toolbar and the tab bar will display the content corresponding to the selected tab.

---

### **4. Camera Tab Screen**

* **Purpose:** To display a list of all cameras associated with the currently connected NVR system.
* **UI Elements:**
    * **Navigation Bar Title:** Displays the name of the connected NVR system.
    * **Camera List:** A list view where each row represents a single camera. Each list item will display basic information such as the camera's name or model.
    * **Interaction:** Tapping on any camera in the list will navigate the user to the **Camera Detail Screen**.

---

### **5. Camera Detail Screen**

* **Purpose:** To display detailed information about a specific camera and allow the user to edit certain parameters.
* **UI Elements:**
    * **Navigation Bar Title:** Displays the name of the selected camera.
    * **Information Fields:** A view displaying various details about the camera. Initially, this will include the camera's IP address.
    * **"Edit" Button:** A button that, when tapped, allows the user to modify the editable fields.
* **Editing Mode:**
    * Upon tapping "Edit," the IP address field will become a text input field.
    * A "Save" or "Done" button will appear to confirm the changes, and a "Cancel" button will be available to discard them.

---

### **6. Application Flow**

This section describes the user's journey through the application under different scenarios.

* **Scenario 1: First-Time Application Launch**
    1.  When the user opens the app for the very first time, there are no saved NVR connections.
    2.  The application will immediately present the **NVR Connection Screen**.
    3.  The user must enter the Server URL, Username, and Password for an NVR and tap "Connect".
    4.  Upon successful connection, the credentials are saved, and the user is taken to the **Main Application Screen** with the **Camera Tab** selected.

* **Scenario 2: Successful Connection to a Default NVR**
    1.  When the user opens the app, it checks for a saved "default" NVR system.
    2.  The app automatically attempts to connect to the default NVR in the background, possibly showing a loading or connecting indicator.
    3.  Once the connection is successful, the user is taken directly to the **Main Application Screen**, with the **Camera Tab** open and populated with the camera list from the connected NVR. From this screen, the user can navigate to the **NVR List Screen** at any time using the dedicated button in the toolbar to switch systems.

* **Scenario 3: Stored Default NVR Fails to Connect**
    1.  When the user opens the app, it attempts to connect to the saved "default" NVR.
    2.  The connection fails (e.g., due to network issues, incorrect password, or the NVR being offline).
    3.  The application will display an error message (e.g., a pop-up or an inline notification) informing the user that the connection to the default NVR failed.
    4.  The user will then be presented with the **NVR List Screen**. From here, they can:
        * Attempt to reconnect to the default NVR by tapping it again.
        * Select a different saved NVR from the list to connect to.
        * Navigate to the **NVR Connection Screen** to add a new system.
