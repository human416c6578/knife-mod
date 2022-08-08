#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <engine> 
#include <nvault>
#include <fun>

#include <inventory>

#pragma reqlib "vip"

native isPlayerVip(id);

#define PLUGIN "Knife Mod"
#define VERSION "1.0" 
#define AUTHOR "MrShark45"

#define TASK_REGEN_ID 9321

#define MAX_HEALTH 255  

#define PREMIUM_KNIFEID 256

new knife_model[33];
new knife_speed[33];

new CVAR_LOWGRAV;
new CVAR_NORMGRAV;
new CVAR_HEALTHREGEN;

new g_iVault;

new g_VipCallback;
new g_PremiumCallback;

new g_msgFadeScreen;

public plugin_init() { 
	
	register_plugin(PLUGIN, VERSION, AUTHOR) 
	
	register_event("CurWeapon","CurWeapon","be","1=1") 
	
	
	register_clcmd("say /knife", "display_knife")

	CVAR_LOWGRAV = register_cvar("km_lowgravity" , "400")
	CVAR_NORMGRAV = get_cvar_pointer("sv_gravity")
	CVAR_HEALTHREGEN = register_cvar("km_healthregen", "5");

	g_VipCallback = menu_makecallback("vip_callback");
	g_PremiumCallback = menu_makecallback("premium_callback");

	RegisterHam(Ham_TakeDamage, "player", "hook_take_damage");

	g_msgFadeScreen = get_user_msgid("ScreenFade");

	g_iVault = nvault_open("KMOD");
}

public plugin_precache() { 
	//Premium
	precache_model("models/llg/v_premium.mdl") 
	precache_model("models/llg/p_premium.mdl") 
	//Vip
	precache_model("models/llg/v_vip_tigertooth.mdl") 
	precache_model("models/llg/p_vip.mdl") 
	//butcher
	precache_model("models/llg/v_butcher.mdl") 
	precache_model("models/llg/p_butcher.mdl") 
	//knife
	precache_model("models/llg/v_knife.mdl") 
	precache_model("models/llg/p_knife.mdl")
} 

public client_disconnected(id){
	if(task_exists(TASK_REGEN_ID + id)) remove_task(TASK_REGEN_ID + id);
}

public display_knife(id) {
	new menu = menu_create( "\rKnife Mod", "menu_handler" );

	menu_additem( menu, "\wDefault Knife \r(Default Knife)", "", 0 );
	menu_additem( menu, "\wButcher Knife \r(Low Gravity)", "", 0 );
	menu_additem( menu, "\wVip Knife \r(400 Start Speed | \yHealth Regen\r)", "", 0, g_VipCallback);
	menu_additem( menu, "\yPremium Knife \r(500 Start Speed | \yx2 Damage\r)", "", 0, g_PremiumCallback);
   
	menu_setprop( menu, MPROP_EXIT, MEXIT_ALL );

	menu_display( id, menu, 0 );
}

public vip_callback( id, menu, item )
{
	if(isPlayerVip(id))
		return ITEM_ENABLED;
	else
		return ITEM_DISABLED;
}

public premium_callback( id, menu, item )
{
	if(inventory_get_item(id, PREMIUM_KNIFEID))
		return ITEM_ENABLED;
	else
		return ITEM_DISABLED;
}

public hook_take_damage(id, inflictor, attacker, Float:damage, damagebits)
{
	if(!is_user_connected(attacker)) return HAM_IGNORED;
	if(get_user_weapon(attacker) != CSW_KNIFE || knife_model[attacker] != 3) return HAM_IGNORED;

	damage *= 2;
	SetHamParamFloat(4, damage);
	return HAM_HANDLED;
} 

public menu_handler(id, menu, item) {
	if ( item == MENU_EXIT )
	{
		menu_destroy( menu );
		return PLUGIN_HANDLED;
	}

	switch(item) 
	{
		case 0:{
			SetKnife(id, 0)
			SetSpeed(id, 0)
		}
		case 1:{
			SetKnife(id, 1)
			SetSpeed(id, 0)
		}
		case 2:{
			SetKnife(id, 2)
			SetSpeed(id, 1)
		}
		case 3:{
			SetKnife(id, 3)
			SetSpeed(id, 2)
		}
		default: return PLUGIN_HANDLED
	}
	SaveData(id)

	menu_destroy( menu );
	return PLUGIN_HANDLED;
} 

public SetKnife(id , Knife) {
	knife_model[id] = Knife
	
	new Clip, Ammo, Weapon = get_user_weapon(id, Clip, Ammo) 
	if ( Weapon != CSW_KNIFE )
		return PLUGIN_HANDLED
	
	new vModel[56],pModel[56]
	
	switch(Knife)
	{
		case 0: {
			format(vModel,55,"models/llg/v_knife.mdl")
			format(pModel,55,"models/llg/p_knife.mdl")
		}
		case 1: {
			format(vModel,55,"models/llg/v_butcher.mdl")
			format(pModel,55,"models/llg/p_butcher.mdl")
		}
		case 2: {
			format(vModel,55,"models/llg/v_vip_tigertooth.mdl")
			format(pModel,55,"models/llg/p_vip.mdl")
		}
		case 3: {
			format(vModel,55,"models/llg/v_premium.mdl")
			format(pModel,55,"models/llg/p_premium.mdl")
		}
	} 
	
	entity_set_string(id, EV_SZ_viewmodel, vModel)
	entity_set_string(id, EV_SZ_weaponmodel, pModel)
	
	return PLUGIN_HANDLED;  
}

public SetSpeed(id, type){
	knife_speed[id] = type;
}

public Float:GetSpeed(id){
	switch(knife_speed[id]){
		case 1:
			return 400.0;
		case 2:
			return 500.0;
	}
	return 250.0;
}

public SetRegen(id, Weapon){
	if(task_exists(TASK_REGEN_ID + id)) remove_task(TASK_REGEN_ID + id);
	if(knife_model[id] != 2 || Weapon != CSW_KNIFE) return;

	set_task(1.0, "RegenHealth", TASK_REGEN_ID + id, _, _, "b");
}

public RegenHealth(task_id){
	new id = task_id - TASK_REGEN_ID;

	if(!is_user_alive(id)) return;

	new health = get_user_health(id);
	new regen_value = get_pcvar_num(CVAR_HEALTHREGEN);

	if(health >= 200) return;

	health = clamp(health + regen_value, 1, 200);

	set_user_health(id, health);

	fade_green(id, 100);
}

public CurWeapon(id){
	new Weapon = read_data(2)
	
	// Set Knife Model
	SetKnife(id, knife_model[id])

	// Regen Ability
	SetRegen(id, Weapon)
	
	// Task Options

	switch(knife_model[id])
	{
		case 0: SetSpeed(id, 0);
		case 1: SetSpeed(id, 0);
		case 2: SetSpeed(id, 1);
		case 3: SetSpeed(id, 2);	
	}
	
	new Float:Gravity = ((knife_model[id] >= 1 && Weapon == CSW_KNIFE)? get_pcvar_float(CVAR_LOWGRAV) : get_pcvar_float(CVAR_NORMGRAV)) / 800.0
	new Float:Speed = (knife_model[id] >= 1 && Weapon == CSW_KNIFE)? GetSpeed(id) : 250.0
	set_user_gravity(id, Gravity)
	set_user_maxspeed(id, Speed)
	
	
	return PLUGIN_HANDLED;
	
}


public client_authorized(id){
	LoadData(id)
}

SaveData(id)
{ 
	new szName[64]
	new vaultkey[64], vaultdata[64]
	get_user_name(id, szName, 63)

	format(vaultkey, 63, "KMOD_%s", szName)
	format(vaultdata, 63, "%d", knife_model[id]);
	nvault_set(g_iVault, vaultkey, vaultdata)

	format(vaultkey, 63, "KMOD2_%s", szName)
	format(vaultdata, 63, "%d", knife_speed[id]);
	nvault_set(g_iVault, vaultkey, vaultdata)
}

LoadData(id) 
{	
	
	new szName[64]
	new vaultkey[64], vaultdata[64]
	get_user_name(id, szName, 63)
	
	format(vaultkey, 63, "KMOD_%s", szName)
	nvault_get(g_iVault, vaultkey, vaultdata, 63)
	knife_model[id] = str_to_num(vaultdata)

	format(vaultkey, 63, "KMOD2_%s", szName)
	nvault_get(g_iVault, vaultkey, vaultdata, 63)
	knife_speed[id] = str_to_num(vaultdata)
} 


stock fade_green(id, ammount)
{    
    //FADE OUT FROM GREEN
    if (ammount > 255)
    ammount = 255
    
    message_begin(MSG_ONE_UNRELIABLE, g_msgFadeScreen, {0,0,0}, id)
    write_short(ammount * 100)    //Durration
    write_short(0)        //Hold
    write_short(0)        //Type
    write_byte(0)    //R
    write_byte(0)    //G
    write_byte(200)    //B
    write_byte(ammount)    //B
    message_end()
} 