$( document ).ready( function(){
    console.log("works like fuck!")
});

$("#check_auszeichnungen").click(function (){
    console.log("Auszeichnungen");
    console.log($(this).attr("checked"));
    if ($(this).attr("checked")) {
        console.log("show annotations");
            $(".text-box").removeClass("leseansicht");
    }
    else {
        console.log("hide annotations");
        $(".text-box").addClass("leseansicht");
    }
});


$("#check_anhang").click(function() {
    console.log("Anhang");
    
    if ($(this).attr("checked")) {
        console.log("show anhang");
            $(".anhang-box").removeClass("collapse");
    }
    else {
        console.log("hide anhang");
        $(".anhang-box").addClass("collapse");
    }
    
});


