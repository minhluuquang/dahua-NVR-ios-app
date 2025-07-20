/**
 * EncryptionModule.js
 *
 * This file contains a self-contained module for performing the hybrid encryption
 * flow. It includes the core EncryptInfo function and its direct dependencies.
 * This serves as a reference implementation.
 *
 * Dependencies:
 * - CryptoJS (for AES encryption): https://cryptojs.gitbook.io/docs/
 * - RSAKey (for RSA encryption, from rsa.js): A common library for JS RSA.
 */

var EncryptionModule = {
  // This property stores the chosen encryption configuration after negotiation.
  encryptMode: null,

  /**
   * Generates a random numeric string of a specified length.
   * It's designed to be recursive to handle lengths greater than what a single
   * call to Math.random() can reliably produce.
   * @param {number} length The desired length of the final numeric string.
   * @returns {string} A random numeric string of the specified length.
   */
  RandomNum: function (length) {
    var self = arguments.callee;
    var resultString = "";

    // Base case: For lengths 16 or less, generate directly.
    if (length <= 16) {
      var randomFloatString = Math.random().toString();
      // A quirky check to avoid non-random-looking results.
      if (
        randomFloatString.substr(randomFloatString.length - length, 1) === "0"
      ) {
        return self(length); // Retry if the first digit is '0'.
      } else {
        resultString = randomFloatString.substring(
          randomFloatString.length - length
        );
      }
    }
    // Recursive step: For lengths greater than 16, build the string in chunks.
    else {
      var chunksOf16 = Math.floor(length / 16);
      for (var i = 0; i < chunksOf16; i++) {
        resultString += self(16);
      }
      resultString += self(length % 16);
    }
    return resultString;
  },

  /**
   * Determines which encryption profile to use by comparing client capabilities
   * with server-supported ciphers. It selects the first compatible profile.
   * @param {object} serverCapabilities - An object from the server, e.g., { cipher: ["AES", "RPAC"] }.
   */
  saveEncrypt: function (serverCapabilities) {
    var self = this;
    // Define the client-side supported encryption profiles in order of preference.
    var clientProfiles = {
      RPAC: { randLen: 32, mode: "CBC" },
      AES: { randLen: 16, mode: "ECB" },
    };

    // Iterate through the client profiles.
    Object.keys(clientProfiles).forEach(function (profileName) {
      // If a compatible profile has already been found, stop.
      if (self.encryptMode) {
        return;
      }
      // Check if the current profile is supported by the server.
      if (serverCapabilities.cipher.includes(profileName)) {
        // If it is, set it as the active mode and stop iterating.
        self.encryptMode = {
          type: profileName,
          info: clientProfiles[profileName],
        };
      }
    });
  },

  /**
   * Performs hybrid encryption on a payload.
   * 1. Selects an encryption profile via saveEncrypt.
   * 2. Generates a random symmetric key (for AES).
   * 3. Encrypts the symmetric key with the server's public RSA key.
   * 4. Encrypts the payload with AES using the plaintext symmetric key.
   * @param {string} rsaPublicKeyString - The public key from the server (N and E components).
   * @param {any} payload - The actual data/payload to encrypt.
   * @param {object} serverCapabilities - The server's supported encryption capabilities.
   * @returns {object} An object containing the encrypted packet.
   */
  EncryptInfo: function (rsaPublicKeyString, payload, serverCapabilities) {
    // Step 1: Determine the encryption profile if not already set.
    if (this.encryptMode === null) {
      this.saveEncrypt(serverCapabilities);
    }

    // Extract the chosen profile's parameters.
    var keyLength = this.encryptMode.info.randLen;
    var aesMode = this.encryptMode.info.mode;
    var profileType = this.encryptMode.type;

    // Step 2: Parse the RSA Public Key from its string representation.
    var publicKey = {};
    var keyParts = rsaPublicKeyString.split(",");
    var nPart = keyParts[0].split(":");
    var ePart = keyParts[1].split(":");
    publicKey[nPart[0]] = nPart[1];
    publicKey[ePart[0]] = ePart[1];

    // Step 3: Generate a random, temporary symmetric key for AES encryption.
    var randomSymmetricKey = this.RandomNum(keyLength);

    // Step 4: Encrypt the symmetric key using the server's public RSA key.
    var rsaEncryptor = new RSAKey();
    rsaEncryptor.setPublic(publicKey.N, publicKey.E);
    var encryptedSymmetricKey = rsaEncryptor.encrypt(randomSymmetricKey);

    // Step 5: Encrypt the actual payload using AES.
    var parsedSymmetricKey = CryptoJS.enc.Utf8.parse(randomSymmetricKey);
    var aesOptions = {
      iv: CryptoJS.enc.Utf8.parse("0000000000000000"), // Static Initialization Vector
      mode: CryptoJS.mode[aesMode],
      padding: CryptoJS.pad.ZeroPadding,
    };
    var encryptedPayload = CryptoJS.AES.encrypt(
      CryptoJS.enc.Utf8.parse(JSON.stringify(payload)),
      parsedSymmetricKey,
      aesOptions
    );

    // Step 6: Assemble the final packet to be sent to the server.
    var resultPacket = {
      cipher: profileType + "-" + keyLength * 8, // e.g., "RPAC-256"
      salt: encryptedSymmetricKey, // The RSA-encrypted symmetric key
      content: encryptedPayload.toString(), // The Base64-encoded AES payload
    };

    return resultPacket;
  },
};
