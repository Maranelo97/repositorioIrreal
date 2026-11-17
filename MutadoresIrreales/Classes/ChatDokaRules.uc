class ChatDokaRules extends GameRules;

var MutChatDokaBots ChatMut;

function bool PreventDeath(Pawn Killed, Controller Killer, class<DamageType> damageType, vector HitLocation)
{
    if (NextGameRules != None && NextGameRules.PreventDeath(Killed, Killer, damageType, HitLocation))
    {
        return true;
    }

    // Si alguien (jugador o bot) mata a un monstruo con un arma ultima (Redeemer, Ion Painter o la
    // Lightning Gun de Murio una banda de gente), a veces un bot festeja. El sorteo se hace una sola
    // vez por disparo (ver TriggerUltimateKillChat)
    if (ChatMut != None && Killer != None && Monster(Killed) != None && damageType != None)
    {
        if (ClassIsChildOf(damageType, class'XWeapons.DamTypeRedeemer'))
            ChatMut.TriggerUltimateKillChat(Killer, class'MutChatDokaBots'.default.RedeemerBit);
        else if (ClassIsChildOf(damageType, class'XWeapons.DamTypeIonBlast'))
            ChatMut.TriggerUltimateKillChat(Killer, class'MutChatDokaBots'.default.IonPainterBit);
        // La Lightning Gun normal (fuera de Murio una banda de gente) no cuenta: solo la del arma ultima
        else if ((ClassIsChildOf(damageType, class'XWeapons.DamTypeSniperShot') || ClassIsChildOf(damageType, class'XWeapons.DamTypeSniperHeadShot'))
            && Killer.Pawn != None && UltiLightningGun(Killer.Pawn.Weapon) != None)
            ChatMut.TriggerUltimateKillChat(Killer, class'MutChatDokaBots'.default.LightningGunBit);
    }

    return false;
}

function ScoreKill(Controller Killer, Controller Killed)
{
    if (NextGameRules != None)
    {
        NextGameRules.ScoreKill(Killer, Killed);
    }

    if (ChatMut != None)
    {
        // Si muere un jugador humano, un bot aliado se burla de el mencionando su nombre
        if (Killed != None && PlayerController(Killed) != None)
        {
            ChatMut.TriggerHumanDeathTaunt(Killed);
        }
        else if (Killed != None && Bot(Killed) != None)
        {
            ChatMut.TriggerBotChat(Bot(Killed), 0.75);
        }
        else if (Bot(Killer) != None)
        {
            ChatMut.TriggerBotChat(Bot(Killer), 0.30);
        }
    }
}

function int NetDamage(int OriginalDamage, int Damage, pawn injured, pawn instigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
    if (NextGameRules != None)
    {
        Damage = NextGameRules.NetDamage(OriginalDamage, Damage, injured, instigatedBy, HitLocation, Momentum, DamageType);
    }

    // Si un bot queda con poca vida tras recibir dano
    if (ChatMut != None && injured != None && Bot(injured.Controller) != None)
    {
        if (injured.Health > 0 && (injured.Health - Damage) > 0 && (injured.Health - Damage) < 40)
        {
            ChatMut.TriggerBotChat(Bot(injured.Controller), 0.45);
        }
    }

    return Damage;
}
