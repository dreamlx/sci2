$(document).ready(function() {
  $('#communication_work_order_processing_opinion').change(function() {
    var opinion = $(this).val();
    if (opinion == '可以通过') {
      $('#communication_work_order_status').val('approved');
    } else if (opinion == '无法通过') {
      $('#communication_work_order_status').val('rejected');
    } else if (opinion && opinion != '') {
      $('#communication_work_order_status').val('processing');
    }
  });
});