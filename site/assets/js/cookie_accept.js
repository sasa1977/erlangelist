function allow() {
  document.cookie = "cookies=true;expires=Wed Jan 01 2200 00:00:00 UTC;path=/";

  if (typeof(article_id) == "string")
    $.ajax("/comments", {
      method: "POST",
      data: {article_id: article_id, "_csrf_token": csrf_token},
      success: function(response){
        $("#comments").html(response);
      }
    });

  $(".cookies-info").removeClass("rejected");
  $(".cookies-info").addClass("allowed");

  closePopup()
}

function reject() {
  document.cookie = "cookies=false";
  $(".cookies-info").removeClass("allowed");
  $(".cookies-info").addClass("rejected");
  closePopup();
}

function closePopup() {
  $("#privacy_note").hide();
}

$(() => {
  $("[data-action = allow_cookies]").on("click", allow);
  $("[data-action = reject_cookies]").on("click", reject);
  $("[data-action = close_cookie_popup]").on("click", closePopup);
})
