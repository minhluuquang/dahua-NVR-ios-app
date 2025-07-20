# Language-Agnostic Guide: Replicating the Hybrid Encryption Flow

## Overview of the Hybrid Encryption Flow

The process you need to replicate is a **hybrid encryption scheme**. This model uses two types of cryptography:

- **Asymmetric (RSA):** Used to safely encrypt a temporary secret key. This is also known as a Key Encapsulation Mechanism (KEM).
- **Symmetric (AES):** Used to encrypt the actual message payload with the temporary secret key. This is much faster for larger data.

The goal is to produce a final JSON object containing the encrypted data and the encapsulated key, which can be securely transmitted to and decrypted by the server.

---

### I. Required Inputs & Constants

Before starting, you will need the following data.

#### Inputs

1.  **Payload:** The data you want to encrypt (e.g., a user's password string).
2.  **RSA Public Key String:** A string containing the server's public key in the format `N:{modulus_hex},E:{exponent_hex}`.
3.  **Server Cipher List:** An array of strings listing the encryption profiles the server supports (e.g., `["AES", "RPAC"]`).

#### Constants: Client-Side Encryption Profiles

You must define a map of client-supported profiles. The order is important.

| Profile Name | Symmetric Key Length | AES Mode |
| :----------- | :------------------- | :------- |
| **`RPAC`**   | 32 bytes (256 bits)  | CBC      |
| **`AES`**    | 16 bytes (128 bits)  | ECB      |

---

### II. Step-by-Step Implementation Guide

Follow these steps in order to create the encrypted packet.

#### Step 1: Select the Encryption Profile

This step determines which set of parameters to use for the encryption.

1.  Iterate through your **Client-Side Encryption Profiles** in the defined order (`RPAC` first, then `AES`).
2.  For each profile name (e.g., "RPAC"), check if it exists within the **Server Cipher List**.
3.  The **first profile you find that exists in both lists** is the one you will use.
4.  Stop immediately after finding the first match.
5.  Store the selected profile's **Symmetric Key Length** and **AES Mode** for the subsequent steps.

_Example_: If your client profiles are `[RPAC, AES]` and the server list is `["AES", "RPAC"]`, your loop will first check "RPAC". It will find a match and select the **RPAC** profile. The loop then stops, and "AES" is never checked.

---

#### Step 2: Generate a Random Symmetric Key

Create the temporary secret key that will be used for the AES encryption.

1.  Using your language's standard cryptographic library, generate a **secure random byte array**.
2.  The length of this byte array must be equal to the **Symmetric Key Length** determined in Step 1 (e.g., 32 bytes for the RPAC profile).

> **Note:** For security and simplicity, use your language's built-in function for generating random bytes (e.g., `crypto.randomBytes` in Node.js, `os.urandom` in Python) rather than replicating the string-based logic of the original `RandomNum` function.

---

#### Step 3: Encrypt the Symmetric Key with RSA (Key Encapsulation)

This step securely "wraps" the symmetric key from Step 2 so only the server can read it.

1.  Parse the **RSA Public Key String**. You will need to extract the modulus (N) and the public exponent (E). These are typically represented as large hexadecimal strings and should be converted to large integers.
2.  Using an RSA library, encrypt the **plaintext random symmetric key** (the byte array from Step 2).
3.  The output will be the encrypted symmetric key. Convert this result into a **hexadecimal string**. This string will be used as the `salt` in the final output.

> **Important:** The original JavaScript appears to perform raw RSA encryption without a standard padding scheme like OAEP or PKCS#1. For compatibility, you may need to find a library that supports this or set the padding mode to "None".

---

#### Step 4: Encrypt the Payload with AES

Now, encrypt the main payload using the key from Step 2.

1.  **Prepare the Payload:** Take the original payload (e.g., `"password123"`) and serialize it into a JSON string (e.g., `"\"password123\""`).
2.  **Encrypt with AES:** Use an AES encryption function with the following parameters:
    - **Data:** The JSON-stringified payload from the previous step.
    - **Key:** The **plaintext random symmetric key** from Step 2 (the byte array).
    - **Mode:** The **AES Mode** from the profile selected in Step 1 (e.g., `CBC` for RPAC).
    - **Initialization Vector (IV):** A static, 16-byte array of all zeros (`0x00000000000000000000000000000000`).
    - **Padding:** **Zero Padding**. This means you must pad the input data with null bytes (`0x00`) until its length is a multiple of the AES block size (16 bytes). This is a critical detail for compatibility.
3.  **Encode the Output:** Take the resulting ciphertext and **Base64 encode** it. This will be the `content` in the final output.

---

#### Step 5: Assemble the Final Output Object

Create a JSON object with the following structure and values derived from the previous steps.

| Key           | Value    | Description                                                        |
| :------------ | :------- | :----------------------------------------------------------------- |
| **`cipher`**  | `String` | The name of the profile and key size in bits (e.g., `"RPAC-256"`). |
| **`salt`**    | `String` | The hex-encoded, RSA-encrypted symmetric key from Step 3.          |
| **`content`** | `String` | The Base64-encoded, AES-encrypted payload from Step 4.             |

This final object is the compatible, encrypted packet ready to be sent to the server.
