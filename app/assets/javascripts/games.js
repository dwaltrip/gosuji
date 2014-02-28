var socket = null;
var modal = new Modal({ closeButton: false });

$(document).ready(function() {
    console.log('$(document).ready handler');

    // new move
    $('#board-form').on('click.new_move', '.tile-container.clickable', function() {
        disable_turn_actions();
        ajax_post_helper(this, { new_move: $(this).data('pos') }, update_game);
    });

    // pass turn
    $('#pass-turn-form').on('submit.pass_turn', function(e) {
        e.preventDefault();
        disable_turn_actions();
        ajax_post_helper(this, null, update_game);
    });

    // undo request approval/rejection
    $(modal.selector).on('click.undo_approval', '#undo-approval-form .button', function(e) {
        e.preventDefault();
        approval_status = $(this).attr('name');

        if (approval_status === "approved") disable_turn_actions();
        ajax_post_helper(this, { undo_status: approval_status }, update_game);

        modal.close();
    });

    // for closing notifications
    $(modal.selector).on('click.ok_button', '.ok-button', function(e) { modal.close(); });

    socket = get_socket();
    socket.emit('subscribe-to-updates', { room_id: window.room_id });
});

function update_game(data) {
    console.log('-- update_game -- data:', data);

    // if both players pass in a row, game is now in scoring mode -- defer to 'update_scoring' function
    if (hasKey(data, 'just_entered_scoring_phase')) update_scoring(data);
    else
    {
        $('#status-message').text(data.status_message);
        $('#black-capture-count').text(data.captures.black);
        $('#white-capture-count').text(data.captures.white);

        if (data.active_player === true) enable_turn_actions();
        if (hasKey(data, 'undo_button_disabled')) $('#undo-button').prop('disabled', data.undo_button_disabled);

        // update necessary tiles. no need to toggle any event listeners, thanks to event delegation
        for(var i = 0, len = data.tiles.length; i < len; i++) {
            var tile = data.tiles[i];
            var $tile = $('#tile-' + tile.pos);

            $tile.removeClass("empty black white playable clickable").addClass(tile.classes);
            if (hasKey(tile, 'image_src')) $tile.find('.tile-image').attr('src', tile.image_src);
        }
    }
}

function update_scoring(data) {
    console.log('-- update_scoring -- data:', data);

    if (hasKey(data, 'just_entered_scoring_phase')) setup_scoring(data);

    $('#done-scoring-button').prop('disabled', false);

    $('#black-point-count').text(data.points.black);
    $('#white-point-count').text(data.points.white);

    for(var i = 0, len = data.tiles.length; i < len; i++) {
        var tile = data.tiles[i];
        var $tile = $('#tile-' + tile.pos);

        $tile.removeClass("dead-stone alive-stone").addClass(tile.classes);
        if (hasKey(tile, 'image_src')) $tile.find('.tile-image').attr('src', tile.image_src);
    }
}

function setup_scoring(data) {
    console.log('-- setup_scoring -- data:', data);

    var $board_form = $('#board-form');
    $board_form.attr('action', data.form_action);

    $('.tile-container.playable').removeClass('playable');
    $('.tile-container.stone').addClass('alive-stone');

    $('#score-container').removeClass('hidden');
    $('#status-message').text(data.status_message);

    $board_form.on('click.mark_dead', '.tile-container.alive-stone', function(e) {
        ajax_post_helper(this, { stone_pos: $(this).data('pos'), mark_as: 'dead' }, update_scoring);
    });

    $board_form.on('click.mark_alive', '.tile-container.dead-stone', function(e) {
        if (e.shiftKey) {
            ajax_post_helper(this, { stone_pos: $(this).data('pos'), mark_as: 'not_dead' }, update_scoring);
        }
    });

    $('#done-scoring-button').show();
    $('#done-scoring-form').on('submit.done_scoring', function(e) {
        e.preventDefault();
        $('#done-scoring-button').prop('disabled', true);
        ajax_post_helper(this, null, done_scoring_callback);
    });

    modal.open({ content: data.instructions });
    disable_turn_actions();
}


function done_scoring_callback(data) {
    console.log('-- done_scoring_callback -- data:', data);

    $('#status-message').text(data.status_message);

    if (data.game_finished) {
        $('.tile-container').removeClass('alive-stone', 'dead-stone');
        $('#done-scoring-button').prop('disabled', true);
        $('#undo-button').prop('disabled', true);
        $('#resign-button').prop('disabled', true);

        modal.open({ content: data.game_finished_message });
    }
}

function disable_turn_actions() {
    $('div.tile-container.clickable').removeClass('clickable');
    $('#pass-button').prop('disabled', true);
}
function enable_turn_actions() {
    $('div.tile-container.playable').addClass('clickable');
    $('#pass-button').prop('disabled', false);
}


function get_socket() {
    console.log('-- sockjs_url: ' + window.sockjs_url + '\n');
    var sockjs = new SockjsClient(window.sockjs_url);

    sockjs.on('connect', function() {
        console.log("sockjs successfully connected with protocol '" + sockjs.protocol + "'");
        sockjs.emit('successfully-connnected', { connection_id: connection_id });
    });

    sockjs.on('close', function() {
        console.log("sockjs connection close. callback args: " + Array.prototype.slice.call(arguments));
    });

    sockjs.on('message', function(data) {
        console.log("inside sockjs.on('message', cb) callback, data= " + JSON.stringify(data));
    });

    sockjs.on('game-update', function(data) {
        console.log("inside sockjs.on('game-update', cb) callback, data= " + JSON.stringify(data));
        update_game(data);
        modal.close();
    });

    sockjs.on('undo-request', function(data) {
        console.log("inside sockjs.on('undo-request', cb) callback, data= " + JSON.stringify(data));
        if (!modal.currentlyDisplayed) modal.open({ content: data.approval_form });
    });

    sockjs.on('scoring-update', function(data) {
        console.log("inside sockjs.on('scoring-update', cb) callback, data= " + JSON.stringify(data));
        update_scoring(data);
    });

    sockjs.on('game-finished', function(data) {
        console.log("inside sockjs.on('game-finished', cb) callback, data= " + JSON.stringify(data));
        done_scoring_callback(data);
    });

    return sockjs;
}

function ajax_post_helper(form_elem, extra_data, on_success_callback) {
    var $form = $(form_elem).closest('form');
    extra_data = extra_data || {};
    extra_data.connection_id = window.connection_id;

    for(var name in extra_data) {
        $('<input />', {
            type: 'hidden',
            name: name,
            value: extra_data[name],
            class: 'hidden-data'
        }).appendTo($form);
    }

    console.log('-- ajax_helper -- $.post for:', $form.attr('id'), '-- $form.serialize():', $form.serialize(), "\n");
    $.post($form.attr('action'), $form.serialize(), on_success_callback, 'json');

    // clear out our hidden data for $form, so future ajax actions have a clean slate
    $('.hidden-data', $form).remove();
}

function hasKey(obj, key) {
    return Object.prototype.hasOwnProperty.call(obj, key);
}

