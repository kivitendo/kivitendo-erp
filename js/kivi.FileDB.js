namespace("kivi.FileDB", function(ns) {
  "use strict";

  const database = 'kivi';
  const store    = 'files';
  const db_version = 1;

  // IndexedDB
  const indexedDB = window.indexedDB || window.webkitIndexedDB || window.mozIndexedDB || window.OIndexedDB || window.msIndexedDB;

  // Create/open database
  let db;
  let request = indexedDB.open(database, db_version);
  request.onupgradeneeded = (event) => {
    ns.create_image_store(event.target.result);
  };
  request.onerror = ns.onerror;
  request.aftersuccess = [];
  request.onsuccess = () => {
    db = request.result;

    db.onerror = (event) => {
      console.error("Error creating/accessing IndexedDB database");
      console.error(event);
    };

    // Interim solution for Google Chrome to create an objectStore. Will be deprecated
    if (db.setVersion) {
      if (db.version != db_version) {
        let setVersion = db.setVersion(db_version);
        setVersion.onsuccess = () =>  {
          ns.create_image_store(db);
        };
      }
    }

    request.aftersuccess.forEach(f => f());
  };

  ns.create_image_store = function (db) {
    db.createObjectStore(store, { autoIncrement : true });
  };

  ns.store_image = function (blob, filename, success) {
    let put_request = ns.open_store("readwrite").add(blob, filename);

    put_request.onsuccess = success;
    put_request.on_error = ns.onerror;
  };

  ns.retrieve_image = function(key, success) {
    let get_request = ns.open_store().objectStore(store).get(key);

    get_request.onsuccess = success;
    get_request.onerror = request.onerror;
  };

  ns.retrieve_all = function(success) {
    let request = ns.open_store().getAll();
    request.onsuccess = (event) => { success(event.target.result); };
    request.onerror = ns.error;
  };

  ns.retrieve_all_keys = function(success) {
    let request = ns.open_store().getAllKeys();
    request.onsuccess = (event) => { success(event.target.result); };
    request.onerror = ns.error;
  };

  ns.delete_all= function() {
    ns.retrieve_all_keys((keys) => {
      keys.forEach((key) => ns.delete_key(key));
    });
  };

  ns.delete_key= function(key, success) {
    let request = ns.open_store("readwrite").delete(key);
    request.onsuccess = (event) => { if (success) success(event.target.result); };
    request.onerror = ns.error;
  };

  ns.open_store = function(mode = "readonly")  {
    return db.transaction([store], mode).objectStore(store);
  };

  ns.onerror = (event) => {
    console.error("Error creating/accessing IndexedDB database");
    console.error(event.errorState);
  };

  ns.with_db = function(success) {
    if (db && db_version == db.version) {
      success();
    } else {
      // assume the page load db init isn't done yet and push it onto the success
      request.aftersuccess.push(success);
    }
  };
});
