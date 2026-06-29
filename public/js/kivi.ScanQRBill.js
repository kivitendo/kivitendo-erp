namespace('kivi.ScanQRBill', function(ns) {

  ns.onScanSuccess = async (decodedText, decodedResult) => {
    // stop camera
    await html5Qrcode.stop();

    // send the scanned text to the server
    const data = [];
    data.push({ name: 'qrtext', value: decodedText });
    data.push({ name: 'action', value: 'ScanQRBill/handle_scan_result' });
    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.onScanFailure = (error) => {
    // handle scan failure, usually better to ignore and keep scanning.
    //console.warn(`Code scan error = ${error}`);
  }

  ns.popupInvalidQRBill = (error) => {
    console.warn('popupInvalidQRBill', error);
    $('#qr_code_invalid_error').text(error);
    $('#qr_code_invalid_modal').modal('open');
  }

  ns.popupVendorNotFound = (vn) => {
    //console.warn('popupVendorNotFound', vn);
    $('#vendor_name').text(vn);
    $('#vendor_not_found_error').modal('open');
  }

  ns.sendTestCode = async (code) => {
    // function to easily send code without scanning
    // use for testing only
    if (html5Qrcode.isScanning) {
      // stop camera
      await html5Qrcode.stop();
    }
    const data = [];
    const codes = [
      "SPC\r\n0200\r\n1\r\nCH4431999123000889012\r\nS\r\nMax Muster & Söhne\r\nMusterstrasse\r\n123\r\n8000\r\nSeldwyla\r\nCH\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n1949.75\r\nCHF\r\nS\r\nSimon Muster\r\nMusterstrasse\r\n1\r\n8000\r\nSeldwyla\r\nCH\r\nQRR\r\n210000000003139471430009017\r\nOrder from 15.10.2020\r\nEPD\r\n//S1/10/1234/11/201021/30/102673386/32/7.7/40/0:30\r\nName AV1: UV;UltraPay005;12345\r\nName AV2: XY;XYService;54321",
      "SPC\n0200\n1\nCH5800791123000889012\nS\nMuster Krankenkasse\nMusterstrasse\n12\n8000\nSeldwyla\nCH\n\n\n\n\n\n\n\n211.00\nCHF\nS\nSarah Beispiel\nMusterstrasse\n1\n8000\nSeldwyla\nCH\nSCOR\nRF240191230100405JSH0438\n\nEPD\n",
      "SPC\n0200\n1\nCH5800791123000889012\nS\nMax Muster & Söhne\nMusterstrasse\n123\n8000\nSeldwyla\nCH\n\n\n\n\n\n\n\n199.95\nCHF\nS\nSarah Beispiel\nMusterstrasse\n1\n78462\nKonstanz\nDE\nSCOR\nRF18539007547034\n\nEPD\n",
      // for testing XSS
      "SPC\r\n0200\r\n1\r\nCH4431999123000889012\r\nS\r\nMax Muster & Söhne\r\nMusterstrasse\r\n123\r\n8000\r\nSeldwyla\r\nCH\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n1949.75\r\nCHF\r\nS\r\nSimon Muster\r\nMusterstrasse\r\n1\r\n8000\r\nSeldwyla\r\nCH\r\nQRR\r\n210000000003139471430009017\r\nOrder from 15.10.2020\r\nEPD\r\n//S1/10/1234/11/201021/30/102673386/32/7.7/40/0:30<script>alert('XSS!');</script>\r\nName AV1: UV;UltraPay005;12345\r\nName AV2: XY;XYService;54321",
      "<script>alert('XSS!');</script>",
    ];
    data.push({ name: 'qrtext', value: codes[code] });
    data.push({ name: 'action', value: 'ScanQRBill/handle_scan_result' });
    $.post("controller.pl", data, kivi.eval_json_result);
  }

});
