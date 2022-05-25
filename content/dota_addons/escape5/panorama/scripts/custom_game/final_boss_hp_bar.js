function UpdateHPBar() {
  $.Msg("Running update HP Bar");
  var data = CustomNetTables.GetTableValue("final_boss", "data");

  if (data) {
    $.Msg("Updating hp bar, data received")
    initialized = true;

    var hp = data.hp;
    var maxHp = data.max;
    var progress = hp/maxHp;

    var container = $('#FinalBossHPContainer');
    container.style['visibility'] = 'visible';

    var progressBar = $('#BossProgressBar');
    progressBar.value = progress;

    var label = $('#HPLabel');
    label.text = `${hp}/${maxHp}`;
  }
}

$.Msg("Running final_boss_hp_bar.js")
var initialized = false;
if (!initialized) {
  $.Msg("Initializing final boss hp bar")
  UpdateHPBar();
}
CustomNetTables.SubscribeNetTableListener( "final_boss", UpdateHPBar );
